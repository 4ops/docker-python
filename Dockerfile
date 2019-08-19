FROM 4ops/alpine-glibc-buildtools:latest AS builder

# From: https://github.com/docker-library/python/blob/fe11c2ed5a3a3a1917f0a37f3f265d81969d09d9/3.6/alpine3.10/Dockerfile

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.6.9

RUN set -ex \
	; wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	; wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	; export GNUPGHOME="$(mktemp -d)" \
	; gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	; gpg --batch --verify python.tar.xz.asc python.tar.xz \
	; { command -v gpgconf > /dev/null && gpgconf --kill all || :; } \
	; rm -rf "$GNUPGHOME" python.tar.xz.asc \
	; mkdir -p /usr/src/python \
	; tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	; rm python.tar.xz

WORKDIR /usr/src/python

ENV LANG C.UTF-8

RUN set -ex \
	; ./configure \
	--build="x86_64-linux-musl" \
	--enable-loadable-sqlite-extensions \
	# --enable-optimizations \
	# --with-lto \
	# --enable-shared \
	--with-system-expat \
	--with-system-ffi \
	--without-ensurepip

RUN set -ex \
	; make -j 2 \
	EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000"

RUN set -ex \
	; make install \
	; find /usr/local -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
	| tr ',' '\n' \
	| sort -u \
	| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	| xargs -rt apk add --no-cache --virtual .python-rundeps \
	; find /usr/local -depth \
	\( \
	\( -type d -a \( -name test -o -name tests \) \) \
	-o \
	\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
	\) -exec rm -rf '{}' + \
	; rm -rf /usr/src/python \
	; cd /usr/local/lib/python*/config-*-x86_64-linux-gnu/ \
	; rm -rf *.o *.a \
	; python3 --version

WORKDIR /

RUN set -ex \
	; cd /usr/local/bin \
	; ln -s idle3 idle \
	; ln -s pydoc3 pydoc \
	; ln -s python3 python \
	; ln -s python3-config python-config

ENV PYTHON_PIP_VERSION 19.2.2
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/0c72a3b4ece313faccb446a96c84770ccedc5ec5/get-pip.py
ENV PYTHON_GET_PIP_SHA256 201edc6df416da971e64cc94992d2dd24bc328bada7444f0c4f2031ae31e8dad

RUN set -ex \
	; wget -O get-pip.py "$PYTHON_GET_PIP_URL" \
	; echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c - \
	; python get-pip.py \
	--no-color \
	--disable-pip-version-check \
	--no-cache-dir \
	"pip==$PYTHON_PIP_VERSION" \
	; find /usr/local -depth \
	\( \
	\( -type d -a \( -name test -o -name tests \) \) \
	-o \
	\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
	\) -exec rm -rf '{}' + \
	; rm -f get-pip.py \
	; pip --version

FROM builder AS cleanup

RUN set -ex \
	; du -hs /usr/local \
	; pip uninstall -y pip \
	; rm -rf /usr/local/lib/python*/ensurepip \
	; rm -rf /usr/local/lib/python*/idlelib \
	; rm -rf /usr/local/lib/python*/distutils/command \
	; rm -rf /usr/local/lib/python*/lib2to3 \
	; rm -rf /usr/local/lib/python*/__pycache__/* \
	; find /usr/local/include/python* -not -name pyconfig.h -type f -exec rm {} \; \
	; find /usr/local/bin -not -name 'python*' \( -type f -o -type l \) -exec rm {} \; \
	; rm -rf /usr/local/share/* \
	; du -hs /usr/local

FROM 4ops/alpine-glibc:3.10.1

ENV LANG C.UTF-8

RUN apk add --no-cache \
	ca-certificates=20190108-r0 \
	expat=2.2.7-r0 \
	libbz2=1.0.6-r7 \
	libffi=3.2.1-r6 \
	readline=8.0.0-r0 \
	sqlite-libs=3.28.0-r0 \
	xz-libs=5.2.4-r0

COPY --from=cleanup /usr/local /usr/local

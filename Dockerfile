FROM 4ops/alpine-glibc-buildtools:latest AS builder

# From: https://github.com/docker-library/python/blob/fe11c2ed5a3a3a1917f0a37f3f265d81969d09d9/3.6/alpine3.10/Dockerfile

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.7.4

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

RUN mkdir -p /python/bin && mkdir -p /python/lib

ENV PATH /python/bin:$PATH
ENV LD_LIBRARY_PATH /python/lib
ENV LD_RUN_PATH /python/lib
ENV PYTHONPATH /python
ENV LANG C.UTF-8

RUN set -ex \
  ; gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
  ; ./configure \
		--prefix=/python \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-optimizations \
		--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--without-ensurepip

RUN set -ex \
  ; make -j "$(nproc)" \
		EXTRA_CFLAGS="-DTHREAD_STACK_SIZE=0x100000" \
		PROFILE_TASK='-m test.regrtest --pgo \
			test_array \
			test_base64 \
			test_binascii \
			test_binhex \
			test_binop \
			test_bytes \
			test_c_locale_coercion \
			test_class \
			test_cmath \
			test_codecs \
			test_compile \
			test_complex \
			test_csv \
			test_decimal \
			test_dict \
			test_float \
			test_fstring \
			test_hashlib \
			test_io \
			test_iter \
			test_json \
			test_long \
			test_math \
			test_memoryview \
			test_pickle \
			test_re \
			test_set \
			test_slice \
			test_struct \
			test_threading \
			test_time \
			test_traceback \
			test_unicode \
		'

RUN set -ex \
  ; make install \
  ; find /python -type f -executable -not \( -name '*tkinter*' \) -exec scanelf --needed --nobanner --format '%n#p' '{}' ';' \
		| tr ',' '\n' \
		| sort -u \
		| awk 'system("[ -e /python/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
		| xargs -rt apk add --no-cache --virtual .python-rundeps \
  ; find /python -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
  ; rm -rf /usr/src/python \
  ; python3 --version

WORKDIR /

RUN set -ex \
  ; cd /python/bin \
  ; ln -s idle3 idle \
  ; ln -s pydoc3 pydoc \
  ; ln -s python3 python \
  ; ln -s python3-config python-config

ENV PYTHON_PIP_VERSION 19.2.2
ENV PYTHON_GET_PIP_URL https://github.com/pypa/get-pip/raw/0c72a3b4ece313faccb446a96c84770ccedc5ec5/get-pip.py
ENV PYTHON_GET_PIP_SHA256 201edc6df416da971e64cc94992d2dd24bc328bada7444f0c4f2031ae31e8dad

ENV PYROOT /python
ENV PYTHONUSERBASE $PYROOT
ENV PIP_USER 1
ENV PIP_IGNORE_INSTALLED 1

RUN set -ex \
  ; wget -O get-pip.py "$PYTHON_GET_PIP_URL" \
  ; echo "$PYTHON_GET_PIP_SHA256 *get-pip.py" | sha256sum -c - \
  ; python get-pip.py \
		--no-color \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
  ; find /python -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
  ; rm -f get-pip.py \
  ; pip --version

FROM 4ops/alpine-glibc:3.10.1

ENV LANG C.UTF-8
ENV PATH /python/bin:$PATH
ENV PYTHONPATH /python

RUN apk add --no-cache expat=2.2.7-r0

COPY --from=builder /python /python

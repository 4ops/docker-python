FROM 4ops/python-dev:3.7.4 AS builder

FROM 4ops/alpine-glibc:3.10.1 AS base

WORKDIR /app

RUN set -ex; \
    addgroup -g 1001 app; \
    adduser -H -D -u 1001 -G app app; \
    chown app /app; \
    echo '#!/bin/sh' > /entrypoint; \
    echo 'exec "$@"' >> /entrypoint; \
    chmod 0755 /entrypoint \
    ; \
    apk add --no-cache bzip2=1.0.6-r7 expat=2.2.7-r0 libbz2=1.0.6-r7 libffi=3.2.1-r6

ENTRYPOINT ["/entrypoint"]

COPY --from=builder /usr/local /usr/local

RUN set -ex; \
    python -VV; \
    gunicorn --version; \
    pipenv --version

# Usage example:
# ---
#
# ARG PYTHON_VERSION="3.6.9"
#
# FROM 4ops/python-dev:${PYTHON_VERSION} AS dev
#
# RUN apk add --no-cache \
#             --virtual=.runtime-dependencies \
#             libmagic="5.37-r0" \
#             libpq="11.5-r0" \
#             openssl="1.1.1c-r0" \
#             postgresql-dev="11.5-r0" \
#             postgresql-libs="11.5-r0" \
#             python3-dev
#
#
# COPY Pipfile Pipfile.lock ./
# RUN pipenv install --system --dev
#
# FROM 4ops/python:${PYTHON_VERSION} AS release
#
# RUN apk add --no-cache \
#             --virtual=.runtime-dependencies \
#             libmagic="5.37-r0" \
#             libpq="11.5-r0" \
#             openssl="1.1.1c-r0" \
#             postgresql-libs="11.5-r0"
#
# COPY --chown=app Pipfile Pipfile.lock /app/
#
# RUN set -ex; \
#     \
#     apk add --no-cache \
#             --virtual=.build-dependencies \
#             bzip2-dev \
#             gcc \
#             linux-headers \
#             make \
#             musl-dev \
#             libffi-dev \
#             openssl-dev \
#             postgresql-dev \
#     ; \
#     pipenv install --system --deploy; \
#     apk --no-cache del .build-dependencies; \
#     pip uninstall --yes pipenv pip; \
#     \
#     find /usr/local -depth \
#       \( \
#         \( -type d -a \( -name test -o -name tests \) \) \
#         -o \
#         \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
#       \) -exec rm -rf '{}' +
#
# COPY --chown=app . .
#
# USER app
# EXPOSE 8000
#
# ---

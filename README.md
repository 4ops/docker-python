# Python

Alpine-based images for speedup builds.

## Dev image

[![](https://images.microbadger.com/badges/image/4ops/python-dev.svg)](https://hub.docker.com/r/4ops/python-dev)

- Build tools (See full list of packages in git repo [4ops/docker-alpine-glibc-buildtools](https://github.com/4ops/docker-alpine-glibc-buildtools))
- Python
- Pip and pipenv
- Gunicorn

## Base image

[![](https://images.microbadger.com/badges/image/4ops/python.svg)](https://hub.docker.com/r/4ops/python)

- Python
- pip, pipenv
- Gunicorn
- bzip2
- expat
- libbz2
- libffi

Also created:

- working directory /app
- user and group app=1001 app=1001
- simple entrypoint

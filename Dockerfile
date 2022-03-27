FROM registry.internal.aleemhaji.com/hope:0.24.0

LABEL org.label-schema.name="home-network"

RUN \
    apt-get update && \
    apt-get install -y shellcheck && \
    apt-get clean

COPY . /src

RUN find /src -iname "*.sh" -print0 | xargs -0 -n1 shellcheck

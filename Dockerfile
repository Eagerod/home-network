FROM registry.internal.aleemhaji.com/hope:0.24.0

LABEL org.label-schema.name="home-network"

RUN \
    apt-get update && \
    apt-get install -y shellcheck && \
    apt-get clean

RUN pip3 install yamllint

COPY . /src

RUN \
    find /src -type f -path ".git" -prune -o \
        -iname "*.sh" -print0 | \
    xargs -0 -n1 shellcheck
RUN \
    find /src -type f -path ".git" -prune -o \
        -iname "*.yaml" -o -iname "*.yml" | \
    grep -v "/src/metallb.yaml" | \
    grep -v "/src/metrics-server.yaml" | \
    xargs yamllint -d "{extends: default, rules: {document-start: disable, line-length: disable}}"

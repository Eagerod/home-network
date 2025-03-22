FROM registry.internal.aleemhaji.com/hope:0.32.0

LABEL org.label-schema.name="home-network"

RUN \
    apt-get update && \
    apt-get install -y \
        jq \
        shellcheck \
        yamllint && \
    apt-get clean

# Not included in the repo, for licencing reasons.
COPY VMware-ovftool-* .
RUN \
    ./VMware-ovftool-* \
        --console \
        --required \
        --eulas-agreed && \
    rm ./VMware-ovftool-* && \
    ln -s $(which python3) /bin/python

COPY . /src

RUN \
    find /src -type f -path ".git" -prune -o \
        -iname "*.sh" -print0 | \
    xargs -0 -n1 shellcheck
RUN \
    find /src -type f -path ".git" -prune -o \
        -iname "*.yaml" -o -iname "*.yml" | \
    grep -vE "/src/infra/cluster/(metallb|calico|nginx-ingress-daemonset-external|nginx-ingress-daemonset-plus-tcp-udp-proxy)\.(yml|yaml)" | \
    grep -vE "/src/(metrics-server|kubernetes-dashboard)\.(yml|yaml)" | \
    xargs yamllint -d "{extends: default, rules: {document-start: disable, line-length: disable}}"

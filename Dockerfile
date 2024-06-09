FROM registry.internal.aleemhaji.com/hope:0.25.2

LABEL org.label-schema.name="home-network"

RUN \
    apt-get update && \
    apt-get install -y \
        jq \
        shellcheck && \
    apt-get clean

RUN pip3 install yamllint

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
    grep -vE "/src/(metallb|metrics-server|kubernetes-dashboard|calico|nginx-ingress-daemonset-external|nginx-ingress-daemonset-plus-tcp-udp-proxy)\.(yml|yaml)" | \
    xargs yamllint -d "{extends: default, rules: {document-start: disable, line-length: disable}}"

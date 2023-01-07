FROM registry.internal.aleemhaji.com/hope:0.25.0

LABEL org.label-schema.name="home-network"

RUN \
    apt-get update && \
    apt-get install -y shellcheck && \
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

RUN find /src -iname "*.sh" -print0 | xargs -0 -n1 shellcheck

FROM registry.internal.aleemhaji.com/hope:0.19.1

# Not included in the repo, for licencing reasons.
COPY VMware-ovftool-* .
RUN \
    ./VMware-ovftool-* \
        --console \
        --required \
        --eulas-agreed && \
    rm ./VMware-ovftool-* && \
    ln -s $(which python3) /bin/python

LABEL org.label-schema.name="home-network"

COPY . /src

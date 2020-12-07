# This Dockerfile is to run everything related the home network from a single
#   predefined image.
# It's set up for DIND, and includes other operations-ey programs like Packer,
#   kubectl, and hope.
FROM debian:10

RUN \
    apt-get update && \
    apt-get install -y \
        apache2-utils \
        apt-transport-https \
        build-essential \
        curl \
        gettext-base \
        gnupg2 \
        lsb-release \
        python3-pip \
        software-properties-common && \
    apt-get clean

# Kubectl
RUN curl -fsS https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list

# Packer
RUN curl -fsS https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Docker
RUN curl -fsS https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

RUN \
    apt-get update && \
    apt-get install -y \
        containerd.io \
        docker-ce \
        docker-ce-cli \
        kubectl \
        packer && \
    apt-get clean

RUN \
    curl -fsSL https://github.com/Eagerod/hope/releases/download/v0.13.1/linux-amd64 -o /bin/hope && \
    chmod 755 /bin/hope && \
    ln -s $(which python3) /bin/python && \
    ln -s $(which pip3) /bin/pip

LABEL org.label-schema.name="home-network"

VOLUME ["/src"]

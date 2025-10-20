FROM debian:12

RUN \
    apt-get update && \
    apt-get install -y \
        curl && \
	apt-get clean

ARG KUBECTL_VERSION=v1.32.1

RUN \
    ARCH="amd64" && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

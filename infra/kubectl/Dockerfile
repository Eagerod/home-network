FROM registry.internal.aleemhaji.com/debian:13.5

RUN \
    apt-get update && \
    apt-get install -y \
        curl \
        jq && \
	apt-get clean

ARG KUBECTL_VERSION=v1.33.13

RUN \
    ARCH="amd64" && \
    curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" -o /usr/bin/kubectl && \
    chmod +x /usr/bin/kubectl

ENTRYPOINT ["kubectl"]

USER 1000

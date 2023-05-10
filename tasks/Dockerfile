FROM registry.internal.aleemhaji.com/kubectl:1.21.0

USER root

RUN \
    apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

USER 1001

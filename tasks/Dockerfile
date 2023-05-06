FROM bitnami/kubectl:1.16.15

USER root

RUN \
    apt-get update && \
    apt-get install -y jq && \
    rm -rf /var/lib/apt/lists/*

USER 1001

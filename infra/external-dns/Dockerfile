FROM registry.internal.aleemhaji.com/kubectl:1.32.1

USER root

RUN apt-get update && \
    apt-get install -y curl && \
    apt-get clean

USER 1001

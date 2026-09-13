FROM registry.internal.aleemhaji.com/kubectl:1.33.13

USER root

RUN apt-get update && \
    apt-get install -y \
        sqlite3 && \
    apt-get clean

USER 1001

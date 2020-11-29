FROM registry.internal.aleemhaji.com/ubuntu:16.04

RUN \
    apt-get update -y && \
    apt-get install -y \
        software-properties-common && \
    add-apt-repository ppa:transmissionbt/ppa && \
    apt-get update -y && \
    apt-get install -y \
        transmission-common \
        transmission-daemon \
        transmission-cli

COPY settings.json /tmp/settings.json
COPY docker-entrypoint.sh docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]

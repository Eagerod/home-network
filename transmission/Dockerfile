FROM registry.internal.aleemhaji.com/ubuntu:20.04

RUN \
    apt-get update -y && \
    apt-get install -y \
        curl \
        software-properties-common && \
    add-apt-repository ppa:transmissionbt/ppa && \
    apt-get update -y && \
    apt-get install -y \
        transmission-common \
        transmission-daemon \
        transmission-cli

COPY settings.json /tmp/settings.json
COPY docker-entrypoint.sh docker-entrypoint.sh
COPY notify.sh /var/lib/scripts/notify.sh

CMD ["./docker-entrypoint.sh"]

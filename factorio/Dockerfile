FROM registry.internal.aleemhaji.com/ubuntu:20.04

RUN \
    apt-get update -y && \
    apt-get install -y \
    	curl \
        xz-utils && \
    apt-get clean

ARG FACTORIO_SERVER_VERSION=1.1.74

RUN \
    curl -sSL https://www.factorio.com/get-download/$FACTORIO_SERVER_VERSION/headless/linux64 -o /tmp/$FACTORIO_SERVER_VERSION.tar.xz && \
    tar -Jxvf /tmp/$FACTORIO_SERVER_VERSION.tar.xz -C /var/lib/ && \
    rm /tmp/$FACTORIO_SERVER_VERSION.tar.xz && \
	ln -s /var/lib/factorio/bin/x64/factorio /usr/bin/factorio && \
	cp /var/lib/factorio/data/server-settings.example.json /var/lib/factorio/data/server-settings.json

ENV FACTORIO_SAVE_DIR=/var/lib/factorio/saves

EXPOSE 34197

COPY docker-entrypoint.sh docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]

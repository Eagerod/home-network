FROM ncfgbase

RUN \
    apt-get update -y && \
    apt-get install -y \
        xz-utils

ENV FACTORIO_SERVER_VERSION 0.17.68

RUN \
    curl -sSL https://www.factorio.com/get-download/$FACTORIO_SERVER_VERSION/headless/linux64 -o /tmp/$FACTORIO_SERVER_VERSION.tar.xz && \
    tar -Jxvf /tmp/$FACTORIO_SERVER_VERSION.tar.xz -C /var/lib/ && \
    rm /tmp/$FACTORIO_SERVER_VERSION.tar.xz 

ENV FACTORIO_DIR /var/lib/factorio
ENV DATA_DIR $FACTORIO_DIR/data
ENV SAVE_DIR $FACTORIO_DIR/saves

RUN ln -s $FACTORIO_DIR/bin/x64/factorio /usr/bin/factorio
RUN cp $DATA_DIR/server-settings.example.json $DATA_DIR/server-settings.json

EXPOSE 34197

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]

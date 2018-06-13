FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y \
	curl \
	xz-utils \
	uuid-runtime

ENV FACTORIO_SERVER_VERSION 0.16.36

RUN curl -sSL https://www.factorio.com/get-download/$FACTORIO_SERVER_VERSION/headless/linux64 -o /tmp/$FACTORIO_SERVER_VERSION.tar.gz
RUN tar -xf /tmp/$FACTORIO_SERVER_VERSION.tar.gz -C /var/lib/
RUN rm /tmp/$FACTORIO_SERVER_VERSION.tar.gz 

ENV FACTORIO_DIR /var/lib/factorio
ENV DATA_DIR $FACTORIO_DIR/data
ENV SAVE_DIR $FACTORIO_DIR/saves

RUN ln -s $FACTORIO_DIR/bin/x64/factorio /usr/bin/factorio

ENV SAVE_GAME ""

ARG AUTH_REQUIRED="true"
ARG SERVER_TOKEN=""
ARG GAME_PUBLIC="true"

RUN cp $DATA_DIR/server-settings.example.json $DATA_DIR/server-settings.json
RUN sed -i -r 's/("require_user_verification"\s*:\s*).*/\1'$AUTH_REQUIRED',/g' $DATA_DIR/server-settings.json
RUN sed -i -r 's/("token"\s*:\s*).*/\1"'$SERVER_TOKEN'",/g' $DATA_DIR/server-settings.json
RUN sed -i -r 's/("public"\s*:\s*).*/\1'$GAME_PUBLIC',/g' $DATA_DIR/server-settings.json

EXPOSE 34197

CMD if [ -z "${SAVE_GAME}" ]; then export SAVE_GAME=$(uuidgen); fi && if [ ! -f "$SAVE_DIR/$SAVE_GAME.zip" ]; then factorio --create $SAVE_DIR/$SAVE_GAME.zip; fi && factorio --server-settings $DATA_DIR/server-settings.json --start-server $SAVE_DIR/$SAVE_GAME.zip

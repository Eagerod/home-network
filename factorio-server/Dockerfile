FROM ubuntu:16.04

ENV TERM dummy
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get upgrade -y

RUN apt-get install -y curl
RUN apt-get install -y xz-utils
RUN apt-get install -y uuid-runtime

ENV FACTORIO_SERVER_VERSION 0.16.36

RUN curl -sSL https://www.factorio.com/get-download/$FACTORIO_SERVER_VERSION/headless/linux64 -o /tmp/$FACTORIO_SERVER_VERSION.tar.gz
RUN tar -xf /tmp/$FACTORIO_SERVER_VERSION.tar.gz -C /var/lib/
RUN rm /tmp/$FACTORIO_SERVER_VERSION.tar.gz 

RUN ln -s /var/lib/factorio/bin/x64/factorio /usr/bin/factorio

RUN cp /var/lib/factorio/data/server-settings.example.json /var/lib/factorio/data/server-settings.json
RUN sed -i -r 's/("require_user_verification"\s*:\s*).*/\1false,/g' /var/lib/factorio/data/server-settings.json

EXPOSE 34197

CMD export SAVE_GAME=$(uuidgen) && factorio --create /var/lib/factorio/saves/$SAVE_GAME.zip && factorio --server-settings /var/lib/factorio/data/server-settings.json --start-server /var/lib/factorio/saves/$SAVE_GAME.zip

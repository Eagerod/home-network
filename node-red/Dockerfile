FROM ncfgbase

RUN curl -sSL https://deb.nodesource.com/setup_10.x | bash -

RUN \
    apt-get update -y && \
    apt-get install -y \
        nodejs

ENV NODE_RED_VERSION 0.20.5

RUN npm install -g --unsafe-perm node-red@$NODE_RED_VERSION

CMD ["node-red"]

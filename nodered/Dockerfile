FROM node:10

ENV NODE_RED_VERSION 0.20.5

RUN npm install -g --unsafe-perm node-red@$NODE_RED_VERSION

COPY npm_packages.txt .

RUN npm install -g $(cat npm_packages.txt)

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]

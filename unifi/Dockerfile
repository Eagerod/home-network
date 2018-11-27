FROM linuxserver/unifi

COPY system.properties /usr/lib/unifi/data/system.properties

ARG IS_DEFAULT=false

RUN echo is_default=${IS_DEFAULT} >> /usr/lib/unifi/data/system.properties

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

# Overwrite the existing `/init` entrypoint with one that updates the inform ip
ENTRYPOINT ["./docker-entrypoint.sh"]

FROM lscr.io/linuxserver/unifi-controller:7.0.23-ls145

COPY system.properties /usr/lib/unifi/data/system.properties

COPY docker-entrypoint.sh docker-entrypoint.sh

# Overwrite the existing `/init` entrypoint with one that updates the inform ip
ENTRYPOINT ["./docker-entrypoint.sh"]

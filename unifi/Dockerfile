FROM linuxserver/unifi-controller:version-6.0.43

COPY system.properties /usr/lib/unifi/data/system.properties

COPY docker-entrypoint.sh docker-entrypoint.sh

# Overwrite the existing `/init` entrypoint with one that updates the inform ip
ENTRYPOINT ["./docker-entrypoint.sh"]

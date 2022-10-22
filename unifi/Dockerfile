FROM registry.internal.aleemhaji.com/unifi-controller:7.2.94

COPY system.properties /config/data/system.properties

COPY docker-entrypoint.sh docker-entrypoint.sh

# Overwrite the existing `/init` entrypoint with one that updates the inform ip
ENTRYPOINT ["./docker-entrypoint.sh"]

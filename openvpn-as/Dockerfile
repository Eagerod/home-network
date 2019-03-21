FROM linuxserver/openvpn-as

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

# Overwrite the existing `/init` entrypoint with one does some housekeeping
ENTRYPOINT ["./docker-entrypoint.sh"]

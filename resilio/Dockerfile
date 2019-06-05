FROM ncfgbase

RUN \
    echo "deb http://linux-packages.resilio.com/resilio-sync/deb resilio-sync non-free" | tee /etc/apt/sources.list.d/resilio-sync.list && \
    curl -sfSL https://linux-packages.resilio.com/resilio-sync/key.asc | apt-key add - && \
    apt-get update -y && \
    apt-get install -y resilio-sync

COPY sync.conf docker-entrypoint.sh ./
RUN chmod 755 docker-entrypoint.sh

EXPOSE 80

CMD ["./docker-entrypoint.sh"]

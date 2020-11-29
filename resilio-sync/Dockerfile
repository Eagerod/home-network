FROM registry.internal.aleemhaji.com/ubuntu:16.04

RUN \
    apt-get update -y && \
    apt-get install -y curl && \
    echo "deb http://linux-packages.resilio.com/resilio-sync/deb resilio-sync non-free" | tee /etc/apt/sources.list.d/resilio-sync.list && \
    curl -sfSL https://linux-packages.resilio.com/resilio-sync/key.asc | apt-key add - && \
    apt-get update -y && \
    apt-get install -y resilio-sync && \
    apt-get clean

COPY sync.conf docker-entrypoint.sh ./

EXPOSE 80

CMD ["./docker-entrypoint.sh"]

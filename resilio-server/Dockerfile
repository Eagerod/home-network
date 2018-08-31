FROM ncfgbase

RUN echo "deb http://linux-packages.resilio.com/resilio-sync/deb resilio-sync non-free" | tee /etc/apt/sources.list.d/resilio-sync.list
RUN curl -sSL https://linux-packages.resilio.com/resilio-sync/key.asc | apt-key add -

RUN \
	apt-get update -y && \
	apt-get install -y resilio-sync

EXPOSE 8888

CMD ["rslsync", "--nodaemon", "--config", ".sync/sync.conf"]


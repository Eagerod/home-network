FROM ncfgbase

RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:transmissionbt/ppa
RUN apt-get update

RUN apt-get install -y \
	transmission-common \
	transmission-daemon \
	transmission-cli

COPY ./settings.json /var/lib/transmission-daemon/info/settings.json

CMD transmission-daemon -f --config-dir /var/lib/transmission-daemon/info --watch-dir /var/lib/transmission-daemon/watch

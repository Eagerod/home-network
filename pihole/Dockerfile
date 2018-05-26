FROM ubuntu:16.04

ENV TERM dumb
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update
RUN apt-get install -y apt-utils
RUN apt-get upgrade -y
RUN apt-get clean

RUN apt-get update
RUN apt-get install -y \
	curl

COPY ./setupVars.conf /etc/pihole/setupVars.conf

RUN apt-get install -y \
	apt-utils \
	dialog \
	debconf \
	dhcpcd5 \
	git \
	iproute2 \
	whiptail

RUN apt-get install -y \
	bc \
	cron \
	curl \
	dnsmasq \
	dnsutils \
	iputils-ping \
	lsof \
	netcat \
	sudo \
	unzip \
	wget \
	idn2 \
	sqlite3

RUN apt-get install -y \
	lighttpd \
	php-common \
	php-cgi \
	php-sqlite3

RUN curl -sSL https://install.pi-hole.net -o ./install.sh

COPY ./install-docker.sh ./install-docker.sh

RUN /bin/bash -x ./install-docker.sh

CMD ["/bin/bash"]

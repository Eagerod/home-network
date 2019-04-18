FROM ncfgbase

# tzdata needed because it seems to be a strict requirement either of mono or
#   of the terraria server itself.
RUN \
    apt-get update -y && \
    apt-get install -y \
    	tzdata \
    	uuid-runtime

# Because this is a ~700MB set of packages, load them up in several layers so
#   that if there's a failure anywhere in between, some major pieces can be
#   recovered from previous layers
RUN apt-get install -y mono-devel
RUN apt-get install -y mono-complete

ENV TSHOCK_VERSION 4.3.25

RUN curl -sSL https://github.com/Pryaxis/TShock/releases/download/v$TSHOCK_VERSION/tshock_$TSHOCK_VERSION.zip -o /tmp/tshock.zip
RUN unzip /tmp/tshock.zip -d /var/lib/tshock

EXPOSE 7777

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

CMD ["./docker-entrypoint.sh"]

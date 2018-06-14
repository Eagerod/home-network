FROM ncfgbase

# tzdata needed because it seems to be a strict requirement either of mono or
#   of the terraria server itself.
RUN apt-get install -y \
	unzip \
	tzdata \
	uuid-runtime

# Because this is a ~700MB set of packages, load them up in several layers so
#   that if there's a failure anywhere in between, some major pieces can be
#   recovered from previous layers
RUN apt-get install -y mono-devel
RUN apt-get install -y mono-complete

ENV SAVE_PATH "/var/lib/terraria/saves"
ENV WORLD ""

RUN curl -sSL https://github.com/Pryaxis/TShock/releases/download/v4.3.25/tshock_4.3.25.zip -o /tmp/tshock.zip
RUN unzip /tmp/tshock.zip -d /var/lib/tshock

EXPOSE 7777

CMD if [ -z "${WORLD}" ]; then export WORLD=$(uuidgen); mono /var/lib/tshock/TerrariaServer.exe -autocreate 2 -worldname $WORLD -worldpath $SAVE_PATH; else mono /var/lib/tshock/TerrariaServer.exe -world "${SAVE_PATH}/${WORLD}.wld"; fi

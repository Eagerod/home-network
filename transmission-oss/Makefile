include ../docker.make

DOCKER_IMAGE_NAME:=transmission-oss
DOCKER_PORT_FORWARDS:=-p 9091:9091

# Note: Because the watch file is a mount, and not a local directory, the
#   "watch-dir-force-generic" parameter had to be added to the settings file.
#   https://forum.transmissionbt.com/viewtopic.php?t=17960
ifeq ($(shell uname),Darwin)
DOCKER_PORT_FORWARDS+=\
	-v ~/Desktop/docker/transmission/downloads:/var/lib/transmission-daemon/downloads \
	-v ~/Desktop/docker/transmission/watch:/var/lib/transmission-daemon/watch \
	-v ~/Desktop/docker/transmission/info/resume:/var/lib/transmission-daemon/info/resume \
	-v ~/Desktop/docker/transmission/info/torrents:/var/lib/transmission-daemon/info/torrents
else ifeq ($(shell uname),Linux)
DOCKER_PORT_FORWARDS+=\
	-v /var/lib/transmission-daemon/downloads:/var/lib/transmission-daemon/downloads \
	-v /var/lib/transmission-daemon/watch:/var/lib/transmission-daemon/watch \
	-v /var/lib/transmission-daemon/info/resume:/var/lib/transmission-daemon/info/resume \
	-v /var/lib/transmission-daemon/info/torrents:/var/lib/transmission-daemon/info/torrents
else
DOCKER_PORT_FORWARDS+=\
	-v D:/DockerTransmission/downloads:/var/lib/transmission-daemon/downloads \
	-v D:/DockerTransmission/watch:/var/lib/transmission-daemon/watch \
	-v D:/DockerTransmission/info/resume:/var/lib/transmission-daemon/info/resume \
	-v D:/DockerTransmission/info/torrents:/var/lib/transmission-daemon/info/torrents
endif

.PHONY: initialize
initialize:
ifeq ($(shell uname),Linux)
	@sudo mkdir -p /var/lib/transmission-daemon/downloads
	@sudo mkdir -p /var/lib/transmission-daemon/watch
	@sudo mkdir -p /var/lib/transmission-daemon/info/resume
	@sudo mkdir -p /var/lib/transmission-daemon/info/torrents
endif

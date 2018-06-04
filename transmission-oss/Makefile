include ../DockerMakefile

DOCKER_IMAGE_NAME:=transmission-oss

# TODO: Test uname on windows machine to make sure that cygwin/mingw are handled
#   correctly.
ifeq ($(shell uname),Darwin)
DOCKER_PORT_FORWARDS:=\
	-p 9091:9091 \
	-v ~/Desktop/docker/transmission/downloads:/var/lib/transmission-daemon/downloads \
	-v ~/Desktop/docker/transmission/watch:/var/lib/transmission-daemon/watch \
	-v ~/Desktop/docker/transmission/resume:/var/lib/transmission-daemon/resume
else
DOCKER_PORT_FORWARDS:=\
	-p 9091:9091 \
	-v D:/DockerTransmission/downloads:/var/lib/transmission-daemon/downloads \
	-v D:/DockerTransmission/watch:/var/lib/transmission-daemon/watch \
	-v D:/DockerTransmission/resume:/var/lib/transmission-daemon/resume
endif

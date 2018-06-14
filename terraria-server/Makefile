include ../DockerMakefile

DOCKER_IMAGE_NAME:=terraria-server
DOCKER_PORT_FORWARDS:=\
	-p 7777:7777 \
	-v D:/DockerTerraria/saves:/var/lib/terraria/saves \
	-e WORLD=$${WORLD}

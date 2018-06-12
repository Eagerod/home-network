include ../DockerMakefile

DOCKER_IMAGE_NAME:=factorio

# SAVE_GAME is an option argument that's managed in the Dockerfile so that if
#   it's omitted from the environment, it'll still be handled properly in the
#   actual server start up.
DOCKER_PORT_FORWARDS:= \
	-p 34197:34197/udp \
	-v D:/DockerFactorio/saves:/var/lib/factorio/saves \
	-e SAVE_GAME=$${SAVE_GAME}

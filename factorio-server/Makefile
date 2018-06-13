include ../DockerMakefile

DOCKER_IMAGE_NAME:=factorio

# SAVE_GAME is an option argument that's managed in the Dockerfile so that if
#   it's omitted from the environment, it'll still be handled properly in the
#   actual server start up.
DOCKER_PORT_FORWARDS:= \
	-p 34197:34197/udp \
	-v D:/DockerFactorio/saves:/var/lib/factorio/saves \
	-e SAVE_GAME=$${SAVE_GAME}


ifneq ($(shell echo $${SERVER_TOKEN}),)
DOCKER_BUILD_ARGS+=SERVER_TOKEN
# DOCKER_PORT_FORWARDS+=-e SERVER_TOKEN=$${SERVER_TOKEN}
endif

ifneq ($(shell echo $${GAME_PUBLIC}),)
# DOCKER_PORT_FORWARDS+=-e GAME_PUBLIC=$${GAME_PUBLIC}
DOCKER_BUILD_ARGS+=GAME_PUBLIC
endif

ifneq ($(shell echo $${AUTH_REQUIRED}),)
# DOCKER_PORT_FORWARDS+=-e AUTH_ENABLED=$${AUTH_ENABLED}
DOCKER_BUILD_ARGS+=AUTH_REQUIRED
endif

include ../DockerMakefile

DOCKER_IMAGE_NAME:=mongodb
DOCKER_PORT_FORWARDS:=\
	-p 27017:27017 \
	-e MONGO_INITDB_ROOT_USERNAME=$${MONGO_INITDB_ROOT_USERNAME} \
	-e MONGO_INITDB_ROOT_PASSWORD=$${MONGO_INITDB_ROOT_PASSWORD}

ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
DOCKER_PORT_FORWARDS+= -v mongodb-data:/data/db
else
DOCKER_PORT_FORWARDS+= -v /var/lib/mongodb/data:/data/db
endif


# Initialization script to be run once on any given machine to set up the
#   /var/lib/data directory with the Mongo database.
# There are documented concerns using MongoDB without docker volumes on Windows
#   and on Mac. If the host machine is Windows, create a docker volume to
#   manage the file storage aspects.
.PHONY: initialize
initialize:
ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
	$(DOCKER) volume create --name mongodb-data -d local
endif

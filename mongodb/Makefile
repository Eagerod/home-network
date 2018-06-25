include ../DockerMakefile

DOCKER_IMAGE_NAME:=mongodb
DOCKER_PORT_FORWARDS:=\
	-p 27017:27017 \
	-e MONGO_INITDB_ROOT_USERNAME=$${MONGO_INITDB_ROOT_USERNAME} \
	-e MONGO_INITDB_ROOT_PASSWORD=$${MONGO_INITDB_ROOT_PASSWORD}

ifeq ($(or $(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin),($(shell uname),Darwin))
DOCKER_PORT_FORWARDS+= -e mongodb-data:/data/db
else
DOCKER_PORT_FORWARDS+= -e /var/lib/mongodb/data:/data/db
endif


# Initialization script to be run once on any given machine to set up the
#   /var/lib/data directory with the Mongo database.
# There are documented concerns using MongoDB without docker volumes on Windows
#   and on Mac. 
# Creates a mysql-ready container running bash, and submits the mysqld
#   initialize command to it with the approprite parameters.
.PHONY: initialize
initialize:
ifeq ($(or $(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin),$(shell uname),Darwin)
	$(DOCKER) volume create --name mongodb-data -d local
endif

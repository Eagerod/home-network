include ../docker.make

MONGODB_CONTAINER_DATA_DIR:=/data/db

# Both Windows and MacOS run into permissions issues when trying to run a
#   MongoDB storage directory on the host, unless permissions are extremely
#   well managed.
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
MONGODB_DOCKER_VOLUME_NAME:=mongodb-data
MONGODB_HOST_DATA_DIR:=$(MONGODB_DOCKER_VOLUME_NAME)
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
MONGODB_HOST_DATA_DIR:=/var/lib/mongodb/data
endif

DOCKER_IMAGE_NAME:=mongodb
DOCKER_PORT_FORWARDS:=\
	-p 27017:27017 \
	-e MONGO_INITDB_ROOT_USERNAME=$${MONGO_INITDB_ROOT_USERNAME} \
	-e MONGO_INITDB_ROOT_PASSWORD=$${MONGO_INITDB_ROOT_PASSWORD} \
	-v $(MONGODB_HOST_DATA_DIR):$(MONGODB_CONTAINER_DATA_DIR)


# Initialization script to be run once on any given machine to set up the
#   /var/lib/data directory with the Mongo database.
# There are documented concerns using MongoDB without docker volumes on Windows
#   and on Mac. If the host machine is Windows, create a docker volume to
#   manage the file storage aspects.
.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
	@if ! $(DOCKER) volume ls --filter name=$(MONGODB_DOCKER_VOLUME_NAME) | tail -1 | grep -q $(MONGODB_DOCKER_VOLUME_NAME); then \
		$(DOCKER) volume create --name $(MONGODB_DOCKER_VOLUME_NAME) -d local; \
	else \
		echo >&2 "Docker volume already exists"; \
	fi
endif

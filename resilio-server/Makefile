include ../docker.make

RESILIO_CONTAINER_SYNC_DIRECTORY:=/.sync
RESILIO_CONTAINER_BACKUPS_DIRECTORY:=/var/lib/resilio-folders

ifeq ($(PLATFORM),$(PLATFORM_MACOS))
RESILIO_HOST_SYNC_DIRECTORY:=~/Desktop/docker/resilio
RESILIO_HOST_BACKUPS_DIRECTORY:=~/Desktop/docker/backups
SUDO:=
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
RESILIO_HOST_SYNC_DIRECTORY:=/var/lib/.sync
RESILIO_HOST_BACKUPS_DIRECTORY:=/var/lib/backups
SUDO:=sudo
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
RESILIO_HOST_SYNC_DIRECTORY:=D:/DockerResilioSync/settings/.sync
RESILIO_HOST_BACKUPS_DIRECTORY:=D:/DockerBackups
SUDO:=
endif

DOCKER_IMAGE_NAME:=resilio-sync
DOCKER_PORT_FORWARDS:=\
	-p 8888:8888\
	-v $(RESILIO_HOST_SYNC_DIRECTORY):$(RESILIO_CONTAINER_SYNC_DIRECTORY)\
	-v $(RESILIO_HOST_BACKUPS_DIRECTORY):$(RESILIO_CONTAINER_BACKUPS_DIRECTORY)\


image: base-image

.INTERMEDIATE: sync-prod.conf
sync-prod.conf:
	@if [ -z "$${RESILIO_SERVER_USERNAME}" ]; then \
		echo >&2 "Failed to find Resilio Sync username in environment. Cannot initialize"; \
		exit -1; \
	fi
	@if [ -z "$${RESILIO_SERVER_PASSWORD}" ]; then \
		echo >&2 "Failed to find Resilio Sync password in environment. Cannot initialize"; \
		exit -1; \
	fi
	sed "s/webui.username/$${RESILIO_SERVER_USERNAME}/g; s/webui.password/$${RESILIO_SERVER_PASSWORD}/g" sync.conf > sync-prod.conf

$(RESILIO_HOST_SYNC_DIRECTORY)/sync.conf: sync-prod.conf
	$(SUDO) mkdir -p $(RESILIO_HOST_SYNC_DIRECTORY)
	$(SUDO) cp sync-prod.conf $(RESILIO_HOST_SYNC_DIRECTORY)/sync.conf

.PHONY: initialize
initialize: $(RESILIO_HOST_SYNC_DIRECTORY)/sync.conf

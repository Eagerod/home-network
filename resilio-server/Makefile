include ../docker.make

REQUIRED_ENV_VARS:=\
	RESILIO_SERVER_USERNAME\
	RESILIO_SERVER_PASSWORD


ifeq ($(PLATFORM),$(PLATFORM_MACOS))
RESILIO_HOST_SYNC_DIRECTORY:=~/Desktop/docker/resilio
SUDO:=
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
RESILIO_HOST_SYNC_DIRECTORY:=/var/lib/.sync
SUDO:=sudo
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
RESILIO_HOST_SYNC_DIRECTORY:=D:/DockerResilioSync/settings/.sync
SUDO:=
endif

setup: $(RESILIO_HOST_SYNC_DIRECTORY)/sync.conf

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

include ../DockerMakefile

DOCKER_IMAGE_NAME:=resilio-sync
DOCKER_PORT_FORWARDS:=-p 8888:8888

ifeq ($(shell uname),Linux)
SETTINGS_ROOT_DIR:=/var/lib/.sync
DOCKER_PORT_FORWARDS+=\
	-v $(SETTINGS_ROOT_DIR):/.sync \
	-v /var/lib/backups:/var/lib/resilio-folders
else
SETTINGS_ROOT_DIR:=/cygdrive/d/DockerResilioSync/settings
DOCKER_PORT_FORWARDS+= \
	-v D:/DockerResilioSync/settings/.sync \
	-v D:/DockerBackups:/var/lib/resilio-folders
endif

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


.PHONY: initialize
initialize: sync-prod.conf
	@if [ -z "$${RESILIO_SERVER_USERNAME}" ]; then \
		echo >&2 "Failed to find Resilio Sync username in environment. Cannot initialize"; \
		exit -1; \
	fi
	@if [ -z "$${RESILIO_SERVER_PASSWORD}" ]; then \
		echo >&2 "Failed to find Resilio Sync password in environment. Cannot initialize"; \
		exit -1; \
    fi

	sudo mkdir -p $(SETTINGS_ROOT_DIR)
	if [ ! -f $(SETTINGS_ROOT_DIR)/sync.conf ]; then \
		sudo cp sync-prod.conf $(SETTINGS_ROOT_DIR)/sync.conf; \
	fi
	rm sync-prod.conf

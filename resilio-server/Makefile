include ../DockerMakefile

DOCKER_IMAGE_NAME:=resilio-sync
DOCKER_PORT_FORWARDS:=\
	-p 8888:8888\
	-v D:/DockerResilioSync/settings:/.sync\
	-v D:/DockerBackups:/var/lib/resilio-folders


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
	if [ ! -d /cygdrive/d/DockerResilioSync ]; then \
		mkdir /cygdrive/d/DockerResilioSync; \
	fi
	if [ ! -d /cygdrive/d/DockerResilioSync/settings ]; then \
		mkdir /cygdrive/d/DockerResilioSync/settings; \
	fi
	if [ ! -f /cygdrive/d/DockerResilioSync/settings/sync.conf ]; then \
		cp sync-prod.conf /cygdrive/d/DockerResilioSync/settings/sync.conf; \
	fi
	rm sync-prod.conf


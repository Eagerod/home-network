include ../docker.make

# Lot of configurations for this container came from the official docker hub
#   page: https://hub.docker.com/r/plexinc/pms-docker/
PLEX_CONTAINER_CONFIG_DIR:=/config

ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
PLEX_DOCKER_VOLUME_NAME:=plex-config
PLEX_HOST_CONFIG_DIR:=$(PLEX_DOCKER_VOLUME_NAME)
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
PLEX_HOST_CONFIG_DIR:=/var/lib/plex
endif

DOCKER_IMAGE_NAME:=plex
DOCKER_PORT_FORWARDS:=\
	-p 32400:32400/tcp\
	-p 3005:3005/tcp\
	-p 8324:8324/tcp\
	-p 32469:32469/tcp\
	-p 1900:1900/udp\
	-p 32410:32410/udp\
	-p 32412:32412/udp\
	-p 32413:32413/udp\
	-p 32414:32414/udp\
	-v $(PLEX_HOST_CONFIG_DIR):$(PLEX_CONTAINER_CONFIG_DIR)\
	$(shell awk '{print " -v "$$2":"$$1}' volumes.txt)


.PHONY: intitialize
initialize:
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
	if ! $(DOCKER) volume ls --filter name=$(PLEX_DOCKER_VOLUME_NAME) | tail -1 | grep -q $(PLEX_DOCKER_VOLUME_NAME); then \
		$(DOCKER) volume create --name $(PLEX_DOCKER_VOLUME_NAME) -d local; \
	else \
		echo >&2 "Docker volume already exists"; \
	fi
endif


setup: plex-volumes.yml mount-volumes

plex-volumes.yml:
	printf "version: '3'\nservices:\n  plex:\n    volumes:\n" > plex-volumes.yml
	awk '{print "      - "$$2":"$$1}' volumes.txt >> plex-volumes.yml

mount-volumes:
	mkdir -p /mnt/downloads /mnt/tv-shows
	sudo umount /mnt/downloads || true
	sudo umount /mnt/tv-shows || true
	sudo mount -t cifs //192.168.0.25/Downloads /mnt/downloads -o user=Aleem
	sudo mount -t cifs //192.168.0.25/TV\ Shows /mnt/tv-shows -o user=Aleem

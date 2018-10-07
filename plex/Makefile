include ../docker.make

# Lot of configurations for this container came from the official docker hub
#   page: https://hub.docker.com/r/plexinc/pms-docker/
PLEX_CONTAINER_CONFIG_DIR:=/config

ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
PLEX_HOST_CONFIG_DIR:=$(PLEX_DOCKER_VOLUME_NAME)
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
PLEX_HOST_CONFIG_DIR:=/var/lib/plex
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

include ../docker.make

TRANSMISSION_CONTAINER_ROOT_DIR:=/var/lib/transmission-daemon
TRANSMISSION_CONTAINER_DOWNLOAD_DIR:=$(TRANSMISSION_CONTAINER_ROOT_DIR)/downloads
TRANSMISSION_CONTAINER_WATCH_DIR:=$(TRANSMISSION_CONTAINER_ROOT_DIR)/watch
TRANSMISSION_CONTAINER_STATS_DIR:=$(TRANSMISSION_CONTAINER_ROOT_DIR)/info/resume
TRANSMISSION_CONTAINER_TORRENTS_DIR:=$(TRANSMISSION_CONTAINER_ROOT_DIR)/info/torrents

# Note: Because the watch file is a mount, and not a local directory, the
#   "watch-dir-force-generic" parameter had to be added to the settings file.
#   https://forum.transmissionbt.com/viewtopic.php?t=17960
ifeq ($(PLATFORM),$(PLATFORM_MACOS))
TRANSMISSION_HOST_ROOT_DIR:=~/Desktop/docker/transmission
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
TRANSMISSION_HOST_ROOT_DIR:=/var/lib/transmission-daemon
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
TRANSMISSION_HOST_ROOT_DIR:=D:/DockerTransmission
endif

# Note: Because each platform uses the same structure after the root directory,
#   these have been pulled out to keep them consistent.
TRANSMISSION_HOST_DOWNLOAD_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/downloads
TRANSMISSION_HOST_WATCH_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/watch
TRANSMISSION_HOST_STATS_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/info/resume
TRANSMISSION_HOST_TORRENTS_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/info/torrents

DOCKER_IMAGE_NAME:=transmission-oss
DOCKER_PORT_FORWARDS:=\
	-p 9091:9091\
	-v $(TRANSMISSION_HOST_DOWNLOAD_DIR):$(TRANSMISSION_CONTAINER_DOWNLOAD_DIR)\
	-v $(TRANSMISSION_HOST_WATCH_DIR):$(TRANSMISSION_CONTAINER_WATCH_DIR)\
	-v $(TRANSMISSION_HOST_STATS_DIR):$(TRANSMISSION_CONTAINER_STATS_DIR)\
	-v $(TRANSMISSION_HOST_TORRENTS_DIR):$(TRANSMISSION_CONTAINER_TORRENTS_DIR)


image: base-image

.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	@sudo mkdir -p $(TRANSMISSION_HOST_DOWNLOAD_DIR)
	@sudo mkdir -p $(TRANSMISSION_HOST_WATCH_DIR)
	@sudo mkdir -p $(TRANSMISSION_HOST_STATS_DIR)
	@sudo mkdir -p $(TRANSMISSION_HOST_TORRENTS_DIR)
endif

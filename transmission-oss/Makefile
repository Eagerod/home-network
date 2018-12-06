include ../docker.make

# Note: Because the watch file is a mount, and not a local directory, the
#   "watch-dir-force-generic" parameter had to be added to the settings file.
#   https://forum.transmissionbt.com/viewtopic.php?t=17960
ifeq ($(PLATFORM),$(PLATFORM_MACOS))
TRANSMISSION_HOST_ROOT_DIR:=~/Desktop/docker/transmission
SUDO:=
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
TRANSMISSION_HOST_ROOT_DIR:=/var/lib/transmission-oss
SUDO:=sudo
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
TRANSMISSION_HOST_ROOT_DIR:=D:/DockerTransmission
SUDO:=
endif

# Note: Because each platform uses the same structure after the root directory,
#   these have been pulled out to keep them consistent.
TRANSMISSION_HOST_DOWNLOAD_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/downloads
TRANSMISSION_HOST_WATCH_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/watch
TRANSMISSION_INFO_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/info
TRANSMISSION_HOST_STATS_DIR:=$(TRANSMISSION_INFO_DIR)/resume
TRANSMISSION_HOST_TORRENTS_DIR:=$(TRANSMISSION_INFO_DIR)/torrents

setup: initialize


.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	@$(SUDO) mkdir -p $(TRANSMISSION_HOST_DOWNLOAD_DIR)
	@$(SUDO) mkdir -p $(TRANSMISSION_HOST_WATCH_DIR)
	@$(SUDO) mkdir -p $(TRANSMISSION_HOST_STATS_DIR)
	@$(SUDO) mkdir -p $(TRANSMISSION_HOST_TORRENTS_DIR)
endif

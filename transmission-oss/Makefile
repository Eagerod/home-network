include ../docker.make

# Note: Because the watch file is a mount, and not a local directory, the
#   "watch-dir-force-generic" parameter had to be added to the settings file.
#   https://forum.transmissionbt.com/viewtopic.php?t=17960
ifeq ($(PLATFORM),$(PLATFORM_MACOS))
TRANSMISSION_HOST_ROOT_DIR:=~/Desktop/docker/transmission-oss
SUDO:=
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
TRANSMISSION_HOST_ROOT_DIR:=/var/lib/transmission-oss
SUDO:=sudo
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
TRANSMISSION_HOST_ROOT_DIR:=D:/DockerTransmissionOss
SUDO:=
endif

# Note: Because each platform uses the same structure after the root directory,
#   these have been pulled out to keep them consistent.
TRANSMISSION_HOST_INFO_DIR:=$(TRANSMISSION_HOST_ROOT_DIR)/info

setup: initialize


# Set up the directories that are needed to run the container, and copy the
#   settings file into the app's volume. Set the owner of the copied file to
#   be the user who owns this directory
.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	@$(SUDO) mkdir -p $(TRANSMISSION_HOST_INFO_DIR)
	@$(SUDO) cp settings.json $(TRANSMISSION_HOST_INFO_DIR)/settings.json
	@$(SUDO) chown $(ls -ld . | awk '{print $3":"$4}') $(TRANSMISSION_HOST_INFO_DIR)/settings.json
endif

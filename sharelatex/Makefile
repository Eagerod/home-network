include ../docker.make

# Note: Have to mount the entire sharelatex directory, even though `./data` is
#   really the only important directory. A temp directory can be created as well
#   but because of sharelatex implementing the temp directory with a `rename`
#   rather than a `mv`, the transaction can't cross file-system boundaries.
# See: https://stackoverflow.com/questions/43206198/
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
SHARELATEX_DOCKER_VOLUME_NAME:=sharelatex-data
SHARELATEX_HOST_DATA_DIR:=$(SHARELATEX_DOCKER_VOLUME_NAME)
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
SHARELATEX_HOST_DATA_DIR:=/var/lib/sharelatex
endif


setup: initialize

.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	sudo mkdir -p $(SHARELATEX_HOST_DATA_DIR)
endif

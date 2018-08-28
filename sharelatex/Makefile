include ../docker.make

SHARELATEX_CONTAINER_DATA_DIR:=/var/lib/sharelatex

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

DOCKER_IMAGE_NAME:=sharelatex
DOCKER_PORT_FORWARDS:=\
	-p 8081:80\
	-v $(SHARELATEX_HOST_DATA_DIR):$(SHARELATEX_CONTAINER_DATA_DIR)


.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
	@if ! $(DOCKER) volume ls --filter name=$(SHARELATEX_DOCKER_VOLUME_NAME) | tail -1 | grep -q $(SHARELATEX_DOCKER_VOLUME_NAME); then \
		$(DOCKER) volume create --name $(SHARELATEX_DOCKER_VOLUME_NAME) -d local; \
	else \
		echo >&2 "Docker volume already exists"; \
	fi
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	sudo mkdir -p $(SHARELATEX_HOST_DATA_DIR)
endif

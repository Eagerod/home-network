# This Makefile fragment is provided as a template for all docker images.
# It provides some provisions for testing, but for the most part, docker-compose
#   should be used for all service starting and stopping.
#
include $(dir $(realpath $(lastword $(MAKEFILE_LIST))))/common.make

SHELL=/bin/bash

DOCKER_IMAGE_NAME:=$(shell basename $(CURDIR))

ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
DOCKER_COMPOSE_IMAGE_PREFIX=$(subst -,,$(shell basename $(realpath $(CURDIR)/..)))
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
DOCKER_COMPOSE_IMAGE_PREFIX=$(shell basename $(realpath $(CURDIR)/..))
endif
DOCKER_COMPOSE_IMAGE_NAME:=$(DOCKER_COMPOSE_IMAGE_PREFIX)_$(DOCKER_IMAGE_NAME)
RUNNING_CONTAINER_NAME=$$($(DOCKER) ps | awk '{if ($$2 == "$(DOCKER_COMPOSE_IMAGE_NAME)") print $$NF;}') 2> /dev/null


.PHONY: kill
kill:
	$(DOCKER) kill $(RUNNING_CONTAINER_NAME) 2> /dev/null || true

.PHONY: shell
shell:
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) bash || echo "Failed to find container"

.PHONY: logs
logs:
	$(ATTACHED_DOCKER) logs -f $(RUNNING_CONTAINER_NAME)

# The setup target is used to determine whether or not a container has been
#   set up for the first time. Individual containers can add dependencies to 
#   the setup target to add in functionality needed to configure themselves.
setup:
	date -u '+%Y-%m-%dT%H:%M:%SZ' > setup

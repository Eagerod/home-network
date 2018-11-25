# This Makefile fragment is provided as a template for all docker images.
# It provides some provisions for testing, but for the most part, docker-compose
#   should be used for all service starting and stopping.
#
include $(dir $(realpath $(lastword $(MAKEFILE_LIST))))/common.make

SHELL=/bin/bash

DOCKER_IMAGE_NAME:=$(shell basename $(CURDIR))

DOCKER_COMPOSE_IMAGE_NAME:=$(DOCKER_COMPOSE_PROJECT_NAME)_$(DOCKER_IMAGE_NAME)
RUNNING_CONTAINER_NAME=$$($(DOCKER) ps --filter name=$(DOCKER_COMPOSE_IMAGE_NAME) -q)

REQUIRED_ENV_VARS:=


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
setup: test-environment
	date -u '+%Y-%m-%dT%H:%M:%SZ' > setup


.PHONY: env-template
env-template:
	if [ ! -f .env ]; then \
		if [ "$(REQUIRED_ENV_VARS)" != "" ]; then \
			touch .env; \
			$(foreach e,$(REQUIRED_ENV_VARS),echo export $(e)= >> .env;) \
		fi; \
	fi


# Helper to verify that all required environment variables are configured in a
#   .env file within a given service's directory. This should help with any
#   deployment to make sure that the required configurations are actually
#   present.
.PHONY: test-environment
test-environment:
	@if [ ! -z "$(REQUIRED_ENV_VARS)" ]; then \
		if [ ! -f .env ]; then \
			echo >&2 "Environment file '.env' for service $(DOCKER_IMAGE_NAME) not found"; \
			exit -1; \
		fi; \
		source .env && for var in $(REQUIRED_ENV_VARS); do \
			if ! printenv $$var > /dev/null; then \
				echo >&2 "Environment variable '$$var' for service $(DOCKER_IMAGE_NAME) is not set."; \
				echo >&2 "Add '$$var' to $(DOCKER_IMAGE_NAME)/.env to build."; \
				exit -1; \
			fi; \
		done; \
	fi

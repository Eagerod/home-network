# This Makefile fragment is provided as a template for all docker images.
# It provides some provisions for testing, but for the most part, docker-compose
#   should be used for all service starting and stopping.
#
include $(dir $(realpath $(lastword $(MAKEFILE_LIST))))/common.make

SHELL=/bin/bash

DOCKER_IMAGE_NAME:=$(shell basename $(CURDIR))

# Paths needed for setting up crons.
PROJECT_ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
CONTAINER_ROOT_DIR=$(PROJECT_ROOT_DIR)/$(DOCKER_IMAGE_NAME)

DOCKER_COMPOSE_IMAGE_NAME:=$(DOCKER_COMPOSE_PROJECT_NAME)_$(DOCKER_IMAGE_NAME)
RUNNING_CONTAINER_NAME=$$($(DOCKER) ps --filter name=$(DOCKER_COMPOSE_IMAGE_NAME) -q)

# Variables provided to make creating backups easy for each service.
BACKUP_CRON_LOCATION:=$(CRON_BASE_PATH)/$(DOCKER_COMPOSE_PROJECT_NAME)-$(DOCKER_IMAGE_NAME)
BACKUP_CRON_STDOUT_LOG:=$(LOGS_DIRECTORY)/$(DOCKER_IMAGE_NAME).stdout.log
BACKUP_CRON_STDERR_LOG:=$(LOGS_DIRECTORY)/$(DOCKER_IMAGE_NAME).stderr.log

CRON_SCHEDULE:=@daily

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


# The backup target is meant to give each service a way of backing up whatever
#   content it generates.
# The only things an individual service/container needs to provide are:
#   - A `backup.sh` script that will be executed with root permissions.
#   - Overwrite the `CRON_SCHEDULE` if daily backups are undesirable. 
.PHONY: backup
backup: check-cron-available $(BACKUP_CRON_LOCATION)


.PHONY: check-cron-available
check-cron-available:
	@if ! test $(CRON_BASE_PATH); then \
		echo >&2 "Failed to find CRON_BASE_PATH for this platform."; \
		exit -1; \
	fi


$(BACKUP_CRON_LOCATION): backup.sh
	@echo "$(CRON_SCHEDULE) root bash $(CONTAINER_ROOT_DIR)/backup.sh > $(BACKUP_CRON_STDOUT_LOG) 2> $(BACKUP_CRON_STDERR_LOG)" > $(BACKUP_CRON_LOCATION)


# `touch` must be present to make this a valid shell script when no required
#   environment variables exist, and a `.env` file doesn't exist either (the
#   behaviour expected when there are no required environment variables) 
.env:
	@if [ "$(REQUIRED_ENV_VARS)" != "" ]; then \
		touch $@; \
		$(foreach e,$(REQUIRED_ENV_VARS),echo export $(e)= >> $@;) \
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

include common.make

SHELL=/bin/bash

DOCKER_CONTAINERS:=\
	nginx \
	pi-hole \
	redis \
	mysql \
	mongodb \
	sharelatex \
	transmission-oss \
	util \
	resilio-server \
	firefly-iii

DOCKER_COMPOSE_EXTRAS:=${DOCKER_COMPOSE_EXTRAS}

PLATFORM_DOCKER_COMPOSE:=$(DOCKER_COMPOSE) -f docker-compose.yml -f $(COMPOSE_PLATFORM_FILE) $(DOCKER_COMPOSE_EXTRAS)
COMPOSE_ENVIRONMENT_FILES=$(foreach c,$(DOCKER_CONTAINERS),$(c)/compose.env)
SETUP_FILES:=$(foreach c,$(DOCKER_CONTAINERS),$(c)/setup)
COMPOSE_ARGUMENTS_FILES:=$(shell find . -iname ".args")
SOURCE_BUILD_ARGS=source $(COMPOSE_ARGUMENTS_FILES)

CRON_BASE_PATH:=/etc/cron.d
INSTALLED_CRON_PATH:=$(CRON_BASE_PATH)/docker-home-network
MYSQL_BACKUP_CRON_PATH:=$(CRON_BASE_PATH)/mysql-backup

INSTALLED_CRON_LOG_BASE:=/var/log/docker-network-init

.PHONY: all
all: setup $(COMPOSE_ENVIRONMENT_FILES) compose-up

.PHONY: setup
setup: volumes $(SETUP_FILES)

$(SETUP_FILES):
	$(MAKE) -C $(@D) setup;

.PHONY: compose-up
compose-up:
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) build
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) up -d

.PHONY: compose-down
compose-down:
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) down

# Building any container requires that all environment files are present.
# For whatever reason, docker-compose reads in environments of services that
#   aren't in any way related to the service that's being started.
.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS): $(COMPOSE_ENVIRONMENT_FILES)
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) build $@
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) up -d $@

# Source each file, and loop over the environments that should have been set,
#   and write those out to the compose env file.
$(COMPOSE_ENVIRONMENT_FILES):
	@if [ -f $(@D)/.env ]; then \
		source $(@D)/.env && grep -o "^\s*export \w*" $(@D)/.env | sed -e 's/^[[:space:]]*//' | sort | uniq | sed -e 's/export \(.*\)/\1/g' | awk '{print $$1"="ENVIRON[$$1]}' >> $@; \
	fi

env: $(COMPOSE_ENVIRONMENT_FILES)

.PHONY: kill
kill: compose-down

.PHONY: reset
reset: kill
	$(DOCKER) container rm $$($(DOCKER) container ls -aq) || true
	$(DOCKER) image rm $$($(DOCKER) image list -q) || true
	$(MAKE)

.PHONY: install
install:
	@if ! sudo [ -f $(INSTALLED_CRON_PATH) ]; then \
		sudo sh -c 'echo "@reboot root $(CURDIR)/startup.sh > $(INSTALLED_CRON_LOG_BASE).log 2> $(INSTALLED_CRON_LOG_BASE).error.log" > $(INSTALLED_CRON_PATH)'; \
	else \
		echo >&2 "The script is already installed"; \
	fi

.PHONY: clean
clean:
	$(DOCKER) container prune -f
	$(DOCKER) image prune -f
	rm -rf $(COMPOSE_ENVIRONMENT_FILES)
	rm -rf $(SETUP_FILES)

.PHONY: install-backups
install-backups:
	mkdir -p /var/lib/backups/mysql
	@if ! sudo [ -f $(MYSQL_BACKUP_CRON_PATH) ]; then \
		sudo sh -c 'echo "@hourly root rsync -ahuDH /var/lib/mysql/ /var/lib/backups/mysql" > $(MYSQL_BACKUP_CRON_PATH)' ; \
	else \
		echo >&2 "The MySQL backup script is already installed"; \
	fi

.PHONY: app
app:
	@if [ -z "$${APP_NAME}" ]; then \
		echo >&2 "Failed to find environment '\$$APP_NAME'"; \
		exit -1; \
	fi

	mkdir -p $${APP_NAME}
	printf 'include ../docker.make\n' > $${APP_NAME}/Makefile
	printf 'FROM ncfgbase\n\nRUN apt-get update -y\n\nCMD ["/bin/bash"]\n' > $${APP_NAME}/Dockerfile

# Volumes need to be created before docker-compose will let any individual
#   service start, so if there are volumes defined in any of the compose files
#   create them before trying to start any containers
.PHONY: volumes
volumes:
	@python -c 'import yaml; print "\n".join([k for k, v in yaml.load(open("docker-compose.yml")).get("volumes", {}).iteritems() if v.get("external", False) == True]);' | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done
	@python -c 'import yaml; print "\n".join([k for k, v in yaml.load(open("$(COMPOSE_PLATFORM_FILE)")).get("volumes", {}).iteritems() if v.get("external", False) == True]);' | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done

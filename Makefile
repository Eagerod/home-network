include common.make

SHELL=/bin/bash

DOCKER_CONTAINERS:=\
	util \
	transmission-oss \
	resilio-server

COMPOSE_CONTAINERS:=\
	pi-hole\
	redis\
	mysql \
	mongodb \
	sharelatex \
	firefly-iii


COMPOSE_ENVIRONMENT_FILES:=$(foreach c,$(COMPOSE_CONTAINERS),$(c)/compose.env)

CRON_BASE_PATH:=/etc/cron.d
INSTALLED_CRON_PATH:=$(CRON_BASE_PATH)/docker-home-network
MYSQL_BACKUP_CRON_PATH:=$(CRON_BASE_PATH)/mysql-backup

INSTALLED_CRON_LOG_BASE:=/var/log/docker-network-init

.PHONY: all
all: $(COMPOSE_ENVIRONMENT_FILES) compose-up $(DOCKER_CONTAINERS)

.PHONY: compose-up
compose-up:
	$(DOCKER_COMPOSE) -f docker-compose.yml -f $(COMPOSE_PLATFORM_FILE) up -d

.PHONY: compose-down
compose-down:
	$(DOCKER_COMPOSE) down

.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS):
	cd $@ && $(MAKE) kill || true
	cd $@ && if [[ -f ".env" ]]; then source $$(pwd)/.env; fi && $(MAKE) release image detached

# Source each file, and loop over the environments that should have been set,
#   and write those out to the compose env file.
$(COMPOSE_ENVIRONMENT_FILES):
	if [ -f $(@D)/.env ]; then \
		source $(@D)/.env && grep -o "^\s*export \w*" $(@D)/.env | sed -e 's/^[[:space:]]*//' | sort | uniq | sed -e 's/export \(.*\)/\1/g' | awk '{print $$1"="ENVIRON[$$1]}' >> $@; \
	fi

env: $(COMPOSE_ENVIRONMENT_FILES)

.PHONY: kill
kill: compose-down
	@$(foreach container, $(DOCKER_CONTAINERS),\
		$(MAKE) -C $(CURDIR)/$(container) kill; \
	)

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
	sed 's/$${APP_NAME}/${APP_NAME}/g' Dockerfile.template > $${APP_NAME}/Dockerfile
	sed 's/$${APP_NAME}/${APP_NAME}/g' Makefile.template > $${APP_NAME}/Makefile

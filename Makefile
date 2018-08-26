SHELL=/bin/bash

ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
else ifeq ($(shell sudo docker ps > /dev/null && echo "pass"),pass)
DOCKER:=sudo docker
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
$(error Cannot communicate with docker daemon. Maybe run `eval $$(docker-machine env $(shell docker-machine ls -q))`)
else
$(error Cannot communicate with docker daemon)
endif

DOCKER_CONTAINERS:=\
	pi-hole\
	util \
	transmission-oss \
	mysql \
	firefly-iii \
	mongodb \
	redis \
	resilio-server \
	sharelatex

CRON_BASE_PATH:=/etc/cron.d
INSTALLED_CRON_PATH:=$(CRON_BASE_PATH)/docker-home-network
MYSQL_BACKUP_CRON_PATH:=$(CRON_BASE_PATH)/mysql-backup

INSTALLED_CRON_LOG_BASE:=/var/log/docker-network-init

.PHONY: all
all: $(DOCKER_CONTAINERS)

.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS):
	cd $@ && $(MAKE) kill || true
	cd $@ && if [[ -f ".env" ]]; then source $$(pwd)/.env; fi && $(MAKE) release image detached

.PHONY: kill
kill:
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

.PHONY: install-backups
install-backups:
	mkdir -p /var/lib/backups/mysql
	@if ! sudo [ -f $(MYSQL_BACKUP_CRON_PATH) ]; then \
		sudo sh -c 'echo "@hourly root rsync -ahuDH /var/lib/mysql/ /var/lib/backups/mysql" > $(MYSQL_BACKUP_CRON_PATH)' ; \
	else \
		echo >&2 "The MySQL backup script is already installed"; \
	fi

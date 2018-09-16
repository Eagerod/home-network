include common.make

SHELL=/bin/bash

DOCKER_CONTAINERS:=$(shell find . -iname Dockerfile -type f | awk -F '/' '{print $$2}')

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

NGINX_REVERSE_PROXY_TEMPLATE_FILE:=nginx/reverse-proxy.template.conf
NGINX_REVERSE_PROXY_FILE:=nginx/reverse-proxy.conf

PIHOLE_LAN_LIST_FILE:=pi-hole/lan.list
PIHOLE_SEARCH_DOMAINS:=home local

# List of environment variables in projects that shouldn't be treated as secret.
SAVE_ENV_VARS=\
	MYSQL_USER\
	MYSQL_DATABASE\
	FF_APP_ENV\
	RESILIO_SERVER_USERNAME


# Docker Compose has some odd conditions that require all containers to be
#   properly configured, even if you're only trying to start one. Because of
#   that, this list will be set as a dependency of anything that starts any
#   containers just to make sure that the containers are built.
# Also ensure git hooks are appropriately set up, so that after any amount of
#   testing or playing around with the repo, hooks will be configured.
ANY_CONTAINER_BUILD_DEPS:=\
	$(COMPOSE_ENVIRONMENT_FILES)\
	$(NGINX_REVERSE_PROXY_FILE)\
	$(PIHOLE_LAN_LIST_FILE)\
	base-image\
	volumes\
	.git/hooks/pre-push

.PHONY: all
all: setup $(COMPOSE_ENVIRONMENT_FILES) compose-up

.PHONY: setup
setup: $(SETUP_FILES)

$(SETUP_FILES):
	$(MAKE) -C $(@D) setup


# Base image is needed for several containers. Make sure that it's available
#   before any attempt at building other containers, or else docker will try to
#   pull an image called `ncfgbase`, and it won't find one.
.PHONY: base-image
base-image:
	$(DOCKER) build . -f BaseUpdatedUbuntuDockerfile -t ncfgbase

.PHONY: compose-up
compose-up: $(ANY_CONTAINER_BUILD_DEPS)
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) build
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) up -d

.PHONY: compose-down
compose-down:
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) down

# Build an individual container, rather than bringing the whole system up.
# Building any container requires that all environment files are present.
# For whatever reason, docker-compose reads in environments of services that
#   aren't in any way related to the service that's being started.
.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS): $(ANY_CONTAINER_BUILD_DEPS)
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) build $@
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) up -d $@

# Source each file, and loop over the environments that should have been set,
#   and write those out to the compose env file.
$(COMPOSE_ENVIRONMENT_FILES):
	@if [ -f $(@D)/.env ]; then \
		source $(@D)/.env && grep -o "^\s*export \w*" $(@D)/.env | sed -e 's/^[[:space:]]*//' | sort | uniq | sed -e 's/export \(.*\)/\1/g' | awk '{print $$1"="ENVIRON[$$1]}' >> $@; \
	fi


# Helper to create all compose environment files.
env: $(COMPOSE_ENVIRONMENT_FILES)


# Helper to print out the full configuration that docker-compose will use to
#   bring up the whole system.
.PHONY: show-config
show-config: $(COMPOSE_ENVIRONMENT_FILES)
	$(SOURCE_BUILD_ARGS) && $(PLATFORM_DOCKER_COMPOSE) config


.PHONY: kill
kill: compose-down


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


# Helper to create a new skeleton application template.
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
	@python .scripts/get_volumes_from_compose_file.py 'docker-compose.yml' | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done
	@python .scripts/get_volumes_from_compose_file.py $(COMPOSE_PLATFORM_FILE) | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done


$(NGINX_REVERSE_PROXY_FILE):
	@python .scripts/get_hostname_container_webserver_port.py 'docker-compose.yml' | while read line; do \
		arr=($${line[@]}); \
		sed "s/"'$${HOSTNAME}'"/$${arr[0]}/g; s/"'$${HOSTPORT}'"/$${arr[1]}/g" $(NGINX_REVERSE_PROXY_TEMPLATE_FILE) >> $(NGINX_REVERSE_PROXY_FILE); \
	done


$(PIHOLE_LAN_LIST_FILE):
	$(foreach domain,$(PIHOLE_SEARCH_DOMAINS),\
		python .scripts/get_hostnames.py 'docker-compose.yml' | while read line; do \
			arr=($${line[@]}); \
			hostname=$${arr[0]}; \
			printf '$${SERVER_IP}	%s.%s.	%s\n' $$hostname $(domain) $$hostname >> $(PIHOLE_LAN_LIST_FILE); \
		done; \
	)

.git/hooks/pre-push:
	ln -s ${PWD}/.scripts/hooks/pre-push.sh .git/hooks/pre-push


# Search though all .env files, and fail the command if any secret is found
#   anywhere in the git repo history. Can really be applied to any repo to
#   audit it.
.PHONY: search-env
search-env:
	find . -iname ".env" -print | xargs $(foreach e,$(SAVE_ENV_VARS),grep -vE '\s*export $(e)' |) awk -F '=' '{print $$2}' | sed '/^\s*$$/d' | grep -v '^$$(' | grep -v '^$${' | tr -d '"' | tr -d "'" | sort | uniq | while read line; do \
		if git rev-list --all | xargs git --no-pager grep $$line; then \
			exit -1; \
		fi \
	done

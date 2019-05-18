include common.make

SHELL=/bin/bash

KUBERNETES_KNOWN_HOST:=192.168.1.54

DOCKER_COMPOSE_EXTRAS:=${DOCKER_COMPOSE_EXTRAS}

AUTOGENERATED_COMPOSE_FILES:=

PRIMARY_COMPOSE_FILE:=docker-compose.yml
COMPOSE_ARGUMENTS_FILES:=$(shell find . -iname ".args")
SOURCE_BUILD_ARGS=$(shell if [ -z "$(COMPOSE_ARGUMENTS_FILES)" ]; then echo true; else echo source $(COMPOSE_ARGUMENTS_FILES); fi)
PLATFORM_DOCKER_COMPOSE=$(SOURCE_BUILD_ARGS) && $(DOCKER_COMPOSE) -p $(DOCKER_COMPOSE_PROJECT_NAME) -f $(PRIMARY_COMPOSE_FILE) -f $(COMPOSE_PLATFORM_FILE) $(foreach f,$(AUTOGENERATED_COMPOSE_FILES), -f $(f)) $(DOCKER_COMPOSE_EXTRAS)
DOCKER_CONTAINERS:=$(shell $(PLATFORM_DOCKER_COMPOSE) config --services)
COMPOSE_ENVIRONMENT_FILES=$(foreach c,$(DOCKER_CONTAINERS),$(c)/compose.env)
SETUP_FILES:=$(foreach c,$(DOCKER_CONTAINERS),$(c)/setup)

CONTAINER_DEBUG_TARGETS:=$(foreach c,$(DOCKER_CONTAINERS),debug/$(c))

INSTALLED_CRON_PATH:=$(CRON_BASE_PATH)/$(DOCKER_COMPOSE_PROJECT_NAME)

INSTALLED_CRON_STDOUT_LOG:=$(LOGS_DIRECTORY)/startup.stdout.log
INSTALLED_CRON_STDERR_LOG:=$(LOGS_DIRECTORY)/startup.stderr.log

PIHOLE_LAN_LIST_FILE:=pi-hole/lan.list
PLEX_VOLUMES_COMPOSE_FILE:=plex/plex-volumes.yml

AUTOGENERATED_COMPOSE_FILES+=$(PLEX_VOLUMES_COMPOSE_FILE)

KUBECONFIG=.kube/config
KUBERNETES_SERVICES=\
	nginx


# Each of these rules is forwarded to the Makefiles in the each service's
#   directory.
FORWARDED_RULES=\
	$(COMPOSE_ENVIRONMENT_FILES) \
	$(PIHOLE_LAN_LIST_FILE) \
	$(PLEX_VOLUMES_COMPOSE_FILE) \
	$(SETUP_FILES)

# List of environment variables in projects that shouldn't be treated as secret.
SAVE_ENV_VARS=\
	MYSQL_USER\
	MYSQL_DATABASE\
	FF_APP_ENV\
	RESILIO_SERVER_USERNAME\
	ADVERTISE_IP\
	DOCKER_REGISTRY_USERNAME

# Docker Compose has some odd conditions that require all containers to be
#   properly configured, even if you're only trying to start one. Because of
#   that, this list will be set as a dependency of anything that starts any
#   containers just to make sure that the containers are built.
# Also ensure git hooks are appropriately set up, so that after any amount of
#   testing or playing around with the repo, hooks will be configured.
ANY_CONTAINER_BUILD_DEPS:=\
	$(COMPOSE_ENVIRONMENT_FILES)\
	$(PIHOLE_LAN_LIST_FILE)\
	$(PLEX_VOLUMES_COMPOSE_FILE)\
	base-image\
	volumes\
	.git/hooks/pre-push\
	.gitignore


.PHONY: all
all: initialize-cluster $(KUBERNETES_SERVICES)

.PHONY: services
services: $(KUBERNETES_SERVICES)

.PHONY: initialize-cluster
initialize-cluster: .kube/config
	kubectl create clusterrolebinding default-cluster-admin --clusterrole=cluster-admin --user=system:serviceaccount:default:default
	kubectl taint node util1 node-role.kubernetes.io/master:NoSchedule-
	kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml

	kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
	kubectl apply -f metallb-config.yaml


.PHONY: network-ip-assignments
network-ip-assignments: $(KUBECONFIG)
	@kubectl apply -f network-ip-assignments.yaml


.PHONY: nginx
nginx: network-ip-assignments domain.crt domain.key
	@sed "s/loadBalancerIP:.*/loadBalancerIP: $$(kubectl get configmap network-ip-assignments -o template="{{.data.nginx}}")/" nginx/nginx.yaml | \
		kubectl apply -f -
	@kubectl create secret tls nginx-certs --cert domain.crt --key domain.key -o yaml --dry-run | \
		kubectl apply -f -
	@kubectl create configmap nginx-config --from-file nginx/nginx.conf -o yaml --dry-run | \
		kubectl apply -f -
	@kubectl create configmap nginx-servers --from-file nginx/nginx.http.conf --from-file nginx/nginx.stream.conf -o yaml --dry-run | \
		kubectl apply -f -


# Because of ConfigMap volumes taking their time to reload, can't just run an
#   `nginx -s restart`, and it's easier to just kill all pods.
# Newer versions of Kubernetes include an option to cycle all pods more
#   gracefully
.PHONY: restart-nginx
restart-nginx:
	kubectl delete pod $$(kubectl get pods | grep nginx | awk '{print $$1}')


$(KUBECONFIG):
	@mkdir -p $(@D)
	@ssh -t util1 "kubectl config view --raw" | sed 's/127.0.0.1/$(KUBERNETES_KNOWN_HOST)/' > $@
	@cp $@ ~/.kube/config


.PHONY: token
token:
	kubectl get secret $$(kubectl get serviceaccount default -o jsonpath={.secrets[0].name}) -o jsonpath={.data.token} | base64 -D && echo


.INTERMEDIATE: domain.crt
domain.crt:
	kubectl cp $$(kubectl get pods | grep certbot | head -1 | awk '{print $$1}'):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/fullchain1.pem domain.crt


.INTERMEDIATE: domain.key
domain.key:
	kubectl cp $$(kubectl get pods | grep certbot | head -1 | awk '{print $$1}'):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/privkey1.pem domain.key


registry/registry-secret.yaml:
	@source .env && \
		sed -e "s/htpasswd:.*/htpasswd: $$(htpasswd -nbB -C 10 $${DOCKER_REGISTRY_USERNAME} $${DOCKER_REGISTRY_PASSWORD} | base64 | head -1)/" \
		registry/registry-secret-template.yaml > $@
	kubectl apply -f $@
	@source .env && \
		kubectl create secret docker-registry registry.internal.aleemhaji.com \
			--docker-server=registry.internal.aleemhaji.com \
			--docker-username=$${DOCKER_REGISTRY_USERNAME} \
			--docker-password=$${DOCKER_REGISTRY_PASSWORD} -o yaml --dry-run | \
		kubectl replace -f -


.PHONY: secrets
.INTERMEDIATE: registry/registry-secret.yaml
secrets: registry/registry-secret.yaml


.PHONY: all
all: setup $(COMPOSE_ENVIRONMENT_FILES) compose-up


.PHONY: setup
setup: $(SETUP_FILES)


# Base image is needed for several containers. Make sure that it's available
#   before any attempt at building other containers, or else docker will try to
#   pull an image called `ncfgbase`, and it won't find one.
.PHONY: base-image
base-image:
	$(DOCKER) build . -f BaseUpdatedUbuntuDockerfile -t ncfgbase

.PHONY: compose-up
compose-up: $(ANY_CONTAINER_BUILD_DEPS)
	$(PLATFORM_DOCKER_COMPOSE) up --build -d

.PHONY: compose-down
compose-down:
	$(PLATFORM_DOCKER_COMPOSE) down

# Build an individual container, rather than bringing the whole system up.
# Building any container requires that all environment files are present.
# For whatever reason, docker-compose reads in environments of services that
#   aren't in any way related to the service that's being started.
.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS): $(ANY_CONTAINER_BUILD_DEPS)
	$(MAKE) -C $@ test-environment
	$(PLATFORM_DOCKER_COMPOSE) up --build -d $@


# Debug phony target to start up a container using docker compose, but also to
#   set it up with std_in available, so even if it's a bash command the
#   container's running, it can still be attached to.
.INTERMEDIATE: $(CONTAINER_DEBUG_FILES)
.PHONY: $(CONTAINER_DEBUG_TARGETS)
$(CONTAINER_DEBUG_TARGETS):
	printf "version: '3'\nservices:\n  %s:\n    stdin_open: true\n" $$(basename $@) > "$$(basename $@)/debug.yml"
	DOCKER_COMPOSE_EXTRAS="-f $$(basename $@)/debug.yml $(DOCKER_COMPOSE_EXTRAS)" $(MAKE) $$(basename $@)
	rm -rf  "$$(basename $@)/debug.yml"


# Send all forwarded rules to the Makefiles that own those files.
# Keep them .PHONY so that the Makefiles for the services are responsible for
#   determining whether or not they need to be rebuilt.
.PHONY: $(FORWARDED_RULES)
$(FORWARDED_RULES):
	$(MAKE) -C $(@D) $(@F)


# Helper to create all compose environment files.
.PHONY: env
env: $(COMPOSE_ENVIRONMENT_FILES)


# Helper to print out the full configuration that docker-compose will use to
#   bring up the whole system.
.PHONY: show-config
show-config: $(COMPOSE_ENVIRONMENT_FILES)
	@$(PLATFORM_DOCKER_COMPOSE) config


.PHONY: kill
kill: compose-down


.PHONY: install
install: $(INSTALLED_CRON_PATH)


$(INSTALLED_CRON_PATH):
	@mkdir -p $(LOGS_DIRECTORY)
	@echo '@reboot root bash $(CURDIR)/startup.sh > $(INSTALLED_CRON_STDOUT_LOG) 2> $(INSTALLED_CRON_STDERR_LOG)' > $(INSTALLED_CRON_PATH)


.PHONY: clean
clean:
	$(DOCKER) container prune -f
	$(DOCKER) image prune -f
	rm -rf $(COMPOSE_ENVIRONMENT_FILES)
	rm -rf $(SETUP_FILES)


.PHONY: backups
backups:
	@find . -maxdepth 2 -iname "backup.sh" -exec dirname {} \; | while read bak; do \
		$(MAKE) -C $${bak} backup; \
	done


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
	@python .scripts/get_volumes_from_compose_file.py $(PRIMARY_COMPOSE_FILE) | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done
	@python .scripts/get_volumes_from_compose_file.py $(COMPOSE_PLATFORM_FILE) | while read line; do \
		if [ ! -z "$$line" ]; then \
			$(DOCKER) volume create $$line; \
		fi \
	done



.git/hooks/pre-push:
	# For whatever reason, this can choose to run despite the file already
	#   existing and having no dependencies. Possibly an issue with having a
	#   symlink as a target?
	ln -sf ${PWD}/.scripts/hooks/pre-push.sh $@


.gitignore-extra:
	@touch $@


.gitignore: Makefile .gitignore-extra
	@rm -f $@
	@curl -sSL https://raw.githubusercontent.com/github/gitignore/master/Global/macOS.gitignore >> $@
	@curl -sSL https://raw.githubusercontent.com/github/gitignore/master/Global/Linux.gitignore >> $@
	@curl -sSL https://raw.githubusercontent.com/github/gitignore/master/Global/SublimeText.gitignore >> $@
	@curl -sSL https://raw.githubusercontent.com/github/gitignore/master/Python.gitignore >> $@
	@cat .gitignore-extra >> $@


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

# Target added specifically for linux to disable system dns once the pi-hole
#   tries to bind to port 53. DNS is needed right up until that point, since
#   everything before then does require looking up/building containers.
.PHONY: disable-system-dns
disable-system-dns:
	@systemctl disable systemd-resolved.service
	@systemctl stop systemd-resolved

# When updating the system, somelines the system DNS needs to be enabled
# again, because the pi-hole has been shut down.
.PHONY: enable-system-dns
enable-system-dns:
	@systemctl enable systemd-resolved.service
	@systemctl start systemd-resolved.service

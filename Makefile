include common.make

SHELL=/bin/bash

KUBERNETES_KNOWN_HOST:=192.168.2.10
KUBERNETES_PROMETHEUS_VERISON=0.1.0

DOCKER_CONTAINERS:=$(shell find . -iname Makefile -mindepth 2 -type f | awk -F '/' '{print $$2}')

DOCKER_COMPOSE_EXTRAS:=${DOCKER_COMPOSE_EXTRAS}

AUTOGENERATED_COMPOSE_FILES:=

PRIMARY_COMPOSE_FILE:=docker-compose.yml
PLATFORM_DOCKER_COMPOSE=$(DOCKER_COMPOSE) -p $(DOCKER_COMPOSE_PROJECT_NAME) -f $(PRIMARY_COMPOSE_FILE) -f $(COMPOSE_PLATFORM_FILE) $(foreach f,$(AUTOGENERATED_COMPOSE_FILES), -f $(f)) $(DOCKER_COMPOSE_EXTRAS)
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
KUBERNETES_SERVICES= \
	redis \
	mongodb \
	nginx \
	registry \
	certbot

REGISTRY_HOSTNAME:=registry.internal.aleemhaji.com

SERVICE_LB_IP = $$(kubectl get configmap network-ip-assignments -o template="{{.data.$(1)}}")
REPLACE_LB_IP = sed "s/loadBalancerIP:.*/loadBalancerIP: $(call SERVICE_LB_IP,$(1))/" $(1)/$(1).yaml


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
	DOCKER_REGISTRY_USERNAME\
	FIREFLY_MYSQL_USER\
	FIREFLY_MYSQL_DATABASE

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
initialize-cluster: $(KUBECONFIG)
	@kubectl taint node util1 node-role.kubernetes.io/master:NoSchedule- || true
	@kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	@kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/aio/deploy/recommended/kubernetes-dashboard.yaml

	@kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.7.3/manifests/metallb.yaml
	@kubectl apply -f metallb-config.yaml

	@kubectl apply -f users.yaml

	@$(MAKE) prometheus
	@$(MAKE) grafana


.PHONY: prometheus
prometheus:
	curl -fsSL https://github.com/coreos/kube-prometheus/archive/v$(KUBERNETES_PROMETHEUS_VERISON).tar.gz | tar xvz

	# https://github.com/coreos/kube-prometheus#quickstart specifically
	#   asks for this process to set up prometheus from the download bundle.
	kubectl apply -f kube-prometheus-$(KUBERNETES_PROMETHEUS_VERISON)/manifests/

	# It can take a few seconds for the above 'create manifests' command to fully create the following resources, so verify the resources are ready before proceeding.
	until kubectl get customresourcedefinitions servicemonitors.monitoring.coreos.com ; do date; sleep 1; echo ""; done
	until kubectl get servicemonitors --all-namespaces ; do date; sleep 1; echo ""; done

	kubectl apply -f kube-prometheus-$(KUBERNETES_PROMETHEUS_VERISON)/manifests/
	rm -rf kube-prometheus-$(KUBERNETES_PROMETHEUS_VERISON)


# Set up the ConfigMaps that are needed to hold network information.
.PHONY: networking
networking: $(KUBECONFIG)
	@kubectl apply -f network-ip-assignments.yaml
	@kubectl apply -f http-services.yaml


# Create Secrets for tls certs.
.PHONY: certificates
certificates: domain.crt domain.rsa.key domain.key keycert.pem
	@kubectl create secret generic certificate-files \
		--from-file tls.crt=domain.crt \
		--from-file tls.key=domain.key \
		--from-file tls.rsa.key=domain.rsa.key \
		-o yaml --dry-run | \
			kubectl apply -f -
	@kubectl create secret generic certificate-file --from-file keycert.pem -o yaml --dry-run | \
		kubectl apply -f -


.INTERMEDIATE: nginx.http.conf
nginx.http.conf:
	@kubectl get configmap http-services -o template={{.data.services}} | while read line; do \
		printf 'upstream %s {\n    server %s:%d;\n}\n\n' \
			$${line} \
			$$(kubectl get service $${line} -o template={{.spec.loadBalancerIP}}) \
			$$(kubectl get service $${line} -o jsonpath='{.spec.ports[0].port}') >> $@; \
	done
	@cat nginx/nginx.http.conf >> $@


.PHONY: nginx
nginx: networking nginx.http.conf certificates
	@$(call REPLACE_LB_IP,nginx) | kubectl apply -f -

	@kubectl create configmap nginx-config --from-file nginx/nginx.conf -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl create configmap nginx-servers --from-file nginx.http.conf --from-file nginx/nginx.stream.conf -o yaml --dry-run | \
		kubectl apply -f -


.PHONY: redis
redis:
	$(call REPLACE_LB_IP,redis) | kubectl apply -f -


.PHONY: mongodb
mongodb: certificates
	$(call REPLACE_LB_IP,mongodb) | kubectl apply -f -
	@kubectl apply -f mongodb/mongodb-backup.yaml


.PHONY: registry
registry:
	@source .env && \
		kubectl create secret generic registry-htpasswd-secret \
			--from-literal "htpasswd=$$(htpasswd -nbB -C 10 $${DOCKER_REGISTRY_USERNAME} $${DOCKER_REGISTRY_PASSWORD})" -o yaml --dry-run | \
		kubectl apply -f -
	@source .env && \
		kubectl create secret docker-registry $(REGISTRY_HOSTNAME) \
			--docker-server $(REGISTRY_HOSTNAME) \
			--docker-username $${DOCKER_REGISTRY_USERNAME} \
			--docker-password $${DOCKER_REGISTRY_PASSWORD} -o yaml --dry-run | \
		kubectl apply -f -
	$(call REPLACE_LB_IP,registry) | kubectl apply -f -
	$(DOCKER) login --username ${DOCKER_REGISTRY_USERNAME} --password $${DOCKER_REGISTRY_PASSWORD} $(REGISTRY_HOSTNAME)


.PHONY: certbot
certbot:
	$(call REPLACE_LB_IP,certbot) | kubectl apply -f -


.PHONY: grafana
grafana:
	$(call REPLACE_LB_IP,grafana) | kubectl apply -f -


.PHONY: mysql
mysql:
	@source .env && \
		kubectl create secret generic mysql-root-password \
			--from-literal "value=$${MYSQL_ROOT_PASSWORD}" -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl apply -f mysql/mysql-volumes.yaml

	@# Make sure mysql is torn down
	@kubectl get services -l 'app=mysql' -o name | xargs kubectl delete
	@kubectl get deployments -l 'app=mysql' -o name | xargs kubectl delete
	@kubectl get services -l 'app=mysql-init' -o name | xargs kubectl delete
	@kubectl get deployments -l 'app=mysql-init' -o name | xargs kubectl delete

	@kubectl apply -f mysql/mysql-init.yaml

	@while [ "$$(kubectl get $$(kubectl get pods -l 'app=mysql-init' -o name) -o template={{.status.phase}})" != "Running" ]; do \
		echo >&2 "MySQL not up yet. Waiting 1 second..."; \
		sleep 1; \
	done

	@# Set up permissions for localhost, and for other machines on the
	@#   Kubernetes pod subnet.
	@# Services should be able to start up jobs that will use root to create
	@#   users
	@source .env && kubectl exec -it \
		$$(kubectl get $$(kubectl get pods -l 'app=mysql-init' -o name) -o template={{.metadata.name}}) -- \
		mysql -e '\
			FLUSH PRIVILEGES; \
			SET PASSWORD FOR root@localhost = PASSWORD("'$${MYSQL_ROOT_PASSWORD}'"); \
			CREATE USER IF NOT EXISTS '"'"'root'"'"'@'"'"'10.244.%.%'"'"'; \
			SET PASSWORD FOR '"'"'root'"'"'@'"'"'10.244.%.%'"'"' = PASSWORD("'$${MYSQL_ROOT_PASSWORD}'"); \
			GRANT ALL PRIVILEGES ON *.* to '"'"'root'"'"'@'"'"'10.244.%.%'"'"' WITH GRANT OPTION; \
			FLUSH PRIVILEGES;'

	@kubectl get services -l 'app=mysql-init' -o name | xargs kubectl delete
	@kubectl get deployments -l 'app=mysql-init' -o name | xargs kubectl delete

	@$(call REPLACE_LB_IP,mysql) | kubectl apply -f -

	@kubectl create configmap mysql-backup --from-file mysql/mysql-backup.sh -o yaml --dry-run | \
		kubectl apply -f -


.PHONY: util
util:
	$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/$@:latest
	$(DOCKER) push $(REGISTRY_HOSTNAME)/$@:latest

	source .env && \
		kubectl create configmap multi-reddit-blob-config \
			--from-literal "subreddit_path=$${MULTI_REDDIT_SUBS_LOCATION}" \
			--from-literal "saved_posts_path=$${MULTI_REDDIT_SAVED_LOCATION}" \
			-o yaml --dry-run | kubectl apply -f -
	source .env && \
		kubectl create secret generic multi-reddit-blob-credentials \
			--from-literal "read_acl=$${DEFAULT_BLOBSTORE_READ_ACL}" \
			--from-literal "write_acl=$${DEFAULT_BLOBSTORE_WRITE_ACL}" \
			-o yaml --dry-run | kubectl apply -f -

	$(call REPLACE_LB_IP,util) | kubectl apply -f -


.PHONY: firefly
firefly:
	@kubectl get jobs -l 'job=firefly-mysql-init' -o name | xargs kubectl delete

	@source .env && \
		kubectl create configmap firefly-config \
			--from-literal "mysql_user=$${FIREFLY_MYSQL_USER}" \
			--from-literal "mysql_database=$${FIREFLY_MYSQL_DATABASE}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic firefly-secrets \
			--from-literal "mysql_password=$${FIREFLY_MYSQL_PASSWORD}" \
			--from-literal "app_key=$${FIREFLY_APP_KEY}" \
			-o yaml --dry-run | kubectl apply -f -

	@$(call REPLACE_LB_IP,firefly) | kubectl apply -f -


# Because of ConfigMap volumes taking their time to reload, can't just run an
#   `nginx -s restart`, and it's easier to just kill all pods.
# Newer versions of Kubernetes include an option to cycle all pods more
#   gracefully
.PHONY: restart-nginx
restart-nginx:
	@kubectl delete pod $$(kubectl get pods | grep nginx | awk '{print $$1}')


.PHONY: mysql-restore
mysql-restore:
	@if [ -z "$${RESTORE_MYSQL_DATABASE}" ]; then \
		echo >&2 "Must supply RESTORE_MYSQL_DATABASE to target restore operation."; \
		exit 1; \
	fi

	@kubectl exec -it \
		$$(kubectl get pod --selector='app=mysql' --field-selector=status.phase=Running -o jsonpath={.items[0].metadata.name}) -- \
		sh -c "MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql -u root -e 'CREATE DATABASE IF NOT EXISTS '$${RESTORE_MYSQL_DATABASE}';'"


	@sed \
		-e 's/$${JOB_CREATION_TIMESTAMP}/'$$(date -u +%Y%m%d%H%M%S)'/' \
		-e 's/$${RESTORE_MYSQL_DATABASE}/'$${RESTORE_MYSQL_DATABASE}'/' \
		 mysql/mysql-restore.yaml | kubectl apply -f -


.PHONY: mysql-shell
mysql-shell:
	source .env && \
		kubectl exec -it $$(kubectl get pods -l 'app=mysql' | tail -1 | awk '{print $$1}') -- \
			sh -c 'MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql'


$(KUBECONFIG):
	@mkdir -p $(@D)
	@ssh -t util1 "kubectl config view --raw" | sed 's/127.0.0.1/$(KUBERNETES_KNOWN_HOST)/' > $@
	@cp $@ ~/.kube/config


.PHONY: token
token:
	@kubectl -n kube-system get secret $$(kubectl -n kube-system get serviceaccount aleem -o jsonpath={.secrets[0].name}) -o jsonpath={.data.token} | base64 -D && echo


.INTERMEDIATE: domain.crt
domain.crt:
	@kubectl cp $$(kubectl get pods | grep certbot | head -1 | awk '{print $$1}'):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/fullchain1.pem domain.crt


.INTERMEDIATE: domain.key
domain.key:
	@kubectl cp $$(kubectl get pods | grep certbot | head -1 | awk '{print $$1}'):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/privkey1.pem domain.key


.INTERMEDIATE: domain.rsa.key
domain.rsa.key: domain.key
	openssl rsa -in domain.key -out domain.rsa.key


.INTERMEDIATE: keycert.pem
keycert.pem: domain.key domain.crt
	@cat domain.key domain.crt > keycert.pem


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

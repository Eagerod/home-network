SHELL=/bin/bash

# Figure out how this machine does docker:
ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
DOCKER:=eval $$(docker-machine env $$(docker-machine ls -q --filter state=Running)) && docker
else ifeq ($(shell sudo docker ps > /dev/null && echo "pass"),pass)
DOCKER:=sudo docker
else
$(error Cannot communicate with docker daemon)
endif

# Platform specific cleaning
UNAME=$(shell uname)

ifeq ($(UNAME),Darwin)
SED_INLINE=sed -i ''
else ifeq ($(UNAME),Linux)
SED_INLINE=sed -i
else ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
SED_INLINE=sed -i
else
$(error Unknown distribution ($(UNAME)) for running this project.)
endif

ROUTER_HOST:=192.168.1.1
ROUTER_HOST_USER:=ubnt@$(ROUTER_HOST)

# Constants and calculated values
KUBERNETES_MASTER:=192.168.2.10
KUBERNETES_HOSTS:=$(shell kubectl get nodes -o jsonpath={.items[*].status.addresses[?\(@.type==\"InternalIP\"\)].address})

KUBERNETES_PROMETHEUS_VERISON=0.1.0
KUBERNETES_DASHBOARD_VERSION=v1.10.1
KUBERNETES_METALLB_VERSION=v0.8.3

AP_IPS=\
	192.168.1.43 \
	192.168.1.46 \
	192.168.1.56

NETWORK_SEARCH_DOMAIN=internal.aleemhaji.com

KUBECONFIG=.kube/config

# COMPLEX_SERVICES are the set of services that require more than just a simple
#   template rule to be run.
COMPLEX_SERVICES= \
	mongodb \
	mysql \
	firefly \
	registry \
	remindmebot \
	openvpnas


# TRIVIAL_SERVICES are the set of services that are deployed by only applying
#   their yaml files.
TRIVIAL_SERVICES:=\
	redis \
	grafana \
	certbot \
	nginx-internal \
	nginx-external \
	pihole \
	plex \
	sharelatex \
	alertmanager \
	dashboard \
	blobstore \
	webcomics \
	tedbot \
	trilium \
	gitea \
	postgres \
	heimdall \
	guacamole


# SIMPLE_SERVICES are the set of services that are deployed by creating a
#   docker image using the Dockerfile in the service's directory, and pushing
#   it to the container registry before applying its yaml file.
SIMPLE_SERVICES:=\
	factorio \
	transmission \
	unifi \
	util \
	resilio \
	slackbot \
	amproxy \
	nodered


KUBERNETES_SERVICES=$(COMPLEX_SERVICES) $(TRIVIAL_SERVICES) $(SIMPLE_SERVICES)

# Some services are mostly just basic services, but require an additional
#   configuration to be pushed before they can properly start.
# Those services are included above, and additional prerequisites are listed
#   here.
nginx: nginx-internal nginx-external
nginx-internal nginx-external: nginx-configurations
util: util-configurations
pihole: pihole-configurations
resilio: resilio-configurations
slackbot: slackbot-configurations
alertmanager: alertmanager-configurations
blobstore: blobstore-configurations
webcomics: webcomics-configurations
certbot: certbot-configurations
nodered: nodered-configurations
tedbot: tedbot-configurations
postgres: postgres-configurations
guacamole: guacamole-configurations

REGISTRY_HOSTNAME:=registry.internal.aleemhaji.com

SERVICE_LB_IP = $$(kubectl get configmap network-ip-assignments -o template='{{index .data "$(1)"}}')
REPLACE_LB_IP = sed "s/loadBalancerIP:.*/loadBalancerIP: $(call SERVICE_LB_IP,$(1))/" $(1)/$(1).yaml

KUBECTL_JOBS = kubectl get jobs -l 'job=$(1)' -o name
KUBECTL_APP_PODS = kubectl get pods -l 'app=$(1)' -o name | sed 's:^pod/::'
KUBECTL_RUNNING_POD = kubectl get pods --field-selector=status.phase=Running -l 'app=$(1)' -o name | sed 's:^pod/::'
KUBECTL_APP_EXEC = kubectl exec $$($(call KUBECTL_RUNNING_POD,$(1)))

KUBECTL_WAIT_FOR_POD = while [ -z "$$($(call KUBECTL_RUNNING_POD,$(1)))" ]; do echo >&2 "$(1) not up yet. Waiting 1 second..."; sleep 1; done

# List of environment variables in projects that shouldn't be treated as secret.
SAVE_ENV_VARS=\
	MYSQL_USER\
	MYSQL_DATABASE\
	FF_APP_ENV\
	RESILIO_SERVER_USERNAME\
	ADVERTISE_IP\
	DOCKER_REGISTRY_USERNAME\
	FIREFLY_MYSQL_USER\
	FIREFLY_MYSQL_DATABASE\
	REMINDMEBOT_USERNAME\
	NODE_RED_MYSQL_USER\
	NODE_RED_MYSQL_DATABASE\
	OPENVPN_PRIMARY_USERNAME\
	OPENVPN_AS_HOSTNAME\
	GUACAMOLE_DB\
	GUACAMOLE_DB_USER


.PHONY: all
all: initialize-cluster $(KUBERNETES_SERVICES)


.PHONY: services
services: $(KUBERNETES_SERVICES)


.PHONY: initialize-cluster
initialize-cluster: $(KUBECONFIG)
	@kubectl taint node util1 node-role.kubernetes.io/master:NoSchedule- || true
	@kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
	@kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/$(KUBERNETES_DASHBOARD_VERSION)/src/deploy/recommended/kubernetes-dashboard.yaml
	@kubectl apply -f metrics-server.yaml

	@kubectl apply -f users.yaml

	@$(MAKE) metallb
	@$(MAKE) prometheus
	@$(MAKE) grafana


.PHONY: metallb
metallb:
	@kubectl apply -f https://raw.githubusercontent.com/google/metallb/$(KUBERNETES_METALLB_VERSION)/manifests/metallb.yaml
	@kubectl apply -f metallb-config.yaml


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


.PHONY: alertmanager-configurations
alertmanager-configurations:
	@kubectl create secret generic alertmanager-main -n monitoring \
		--from-file alertmanager.yaml=alertmanager/alertmanager-config.yaml \
		-o yaml --dry-run | \
			kubectl apply -f -
	@echo "Alertmanager configuration updated. Run this once volumes have updated:"
	@echo "    curl -X POST https://alertmanager.internal.aleemhaji.com/-/reload"


# Set up the ConfigMaps that are needed to hold network information.
.PHONY: networking
networking: $(KUBECONFIG)
	@kubectl apply -f network-ip-assignments.yaml
	@kubectl apply -f http-services.yaml
	@kubectl apply -f metallb-config.yaml


.PHONY: crons
crons: base-image
	@$(DOCKER) pull $(REGISTRY_HOSTNAME)/rsync:latest
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/rsync:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/rsync:latest

	@kubectl apply -f crons/rsync-jobs.yaml

	@kubectl get configmap cronjobs -o go-template={{.data._keys}} | while read line; do \
		sh -c "$$(kubectl get configmap cronjobs -o template={{.data.$${line}}} | tr '\n' ' ') envsubst < crons/rsync-cron.yaml" | \
			kubectl apply -f -; \
	done

	@source .env && kubectl create secret generic namesilo-api-key \
		--from-literal value=$${NAMESILO_API_KEY} \
		-o yaml --dry-run | \
			kubectl apply -f -
	@kubectl apply -f crons/dns-cron.yaml


.INTERMEDIATE: 00-upstream.http.conf
00-upstream.http.conf:
	@kubectl get configmap http-services -o template={{.data.default}} | while read line; do \
		printf 'upstream %s {\n    server %s:%d;\n}\n\n' \
			$${line} \
			$$(kubectl get service $${line} -o template={{.spec.loadBalancerIP}}) \
			$$(kubectl get service $${line} -o jsonpath='{.spec.ports[0].port}') >> $@; \
	done
	@kubectl get configmap http-services -o template={{.data.monitoring}} | while read line; do \
		printf 'upstream %s {\n    server %s:%d;\n}\n\n' \
			$${line} \
			$$(kubectl get service -n monitoring $${line} -o template={{.spec.loadBalancerIP}}) \
			$$(kubectl get service -n monitoring $${line} -o jsonpath='{.spec.ports[0].port}') >> $@; \
	done
	@kubectl get configmap http-services -o template='{{ index .data "kube-system" }}' | while read line; do \
		printf 'upstream %s {\n    server %s:%d;\n}\n\n' \
			$${line} \
			$$(kubectl get service -n kube-system $${line} -o template={{.spec.loadBalancerIP}}) \
			$$(kubectl get service -n kube-system $${line} -o jsonpath='{.spec.ports[0].port}') >> $@; \
	done


.PHONY: $(TRIVIAL_SERVICES)
$(TRIVIAL_SERVICES):
	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


.PHONY: $(SIMPLE_SERVICES)
$(SIMPLE_SERVICES):
	@$(DOCKER) pull $(REGISTRY_HOSTNAME)/$@:latest
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/$@:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/$@:latest

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


# Do a full deployment of a service, including updating networking info and
#   having pihole take on new configurations.
.PHONY: complete-%
complete-%: networking % reload-nginx reload-pihole


.PHONY: reload-nginx-internal
reload-nginx-internal:
	@wait_time=60 && \
	current_nginx_config=$$($(call KUBECTL_APP_EXEC,nginx-internal) -- find /etc/nginx/conf.d -mindepth 1 -type d) && \
	$(MAKE) nginx-configurations && \
	printf "Waiting for new nginx configs to be loaded into the container" 1>&2 && \
	until [ "$$($(call KUBECTL_APP_EXEC,nginx-internal) -- find /etc/nginx/conf.d -mindepth 1 -type d)" != "$${current_nginx_config}" ]; do \
		printf '.' 1>&2; \
		sleep 1; \
		wait_time=$$((wait_time - 1)); \
		if [ $${wait_time} -eq 0 ]; then \
			echo >&2 ""; \
			echo >&2 "Kubernetes hasn't updated nginx configurations in 60 seconds."; \
			echo >&2 "Configurations are probably unchanged."; \
			exit; \
		fi; \
	done && \
	printf '\n' 1>&2

	$(call KUBECTL_APP_EXEC,nginx-internal) -- nginx -s reload


.PHONY: reload-nginx-external
reload-nginx-external:
	@wait_time=60 && \
	current_nginx_config=$$($(call KUBECTL_APP_EXEC,nginx-external) -- find /etc/nginx/conf.d -mindepth 1 -type d) && \
	$(MAKE) nginx-configurations && \
	printf "Waiting for new nginx configs to be loaded into the container" 1>&2 && \
	until [ "$$($(call KUBECTL_APP_EXEC,nginx-external) -- find /etc/nginx/conf.d -mindepth 1 -type d)" != "$${current_nginx_config}" ]; do \
		printf '.' 1>&2; \
		sleep 1; \
		wait_time=$$((wait_time - 1)); \
		if [ $${wait_time} -eq 0 ]; then \
			echo >&2 ""; \
			echo >&2 "Kubernetes hasn't updated nginx configurations in 60 seconds."; \
			echo >&2 "Configurations are probably unchanged."; \
			exit; \
		fi; \
	done && \
	printf '\n' 1>&2

	$(call KUBECTL_APP_EXEC,nginx-external) -- nginx -s reload


# Since the pihole mounts its volumes as individual files, Kubernetes doesn't
#   automatically push updated contents to the pods.
# Update the pi-hole configs, then update replicas with the new file contents.
.PHONY: reload-pihole
reload-pihole: pihole-configurations kube.list
	@$(call KUBECTL_APP_PODS,pihole) | while read line; do \
		uuid=$$(uuidgen) && \
		kubectl cp kube.list $${line}:/etc/pihole/kube.$${uuid}.list; \
		kubectl exec $${line} -- chown root:root /etc/pihole/kube.$${uuid}.list; \
		kubectl exec $${line} -- sh -c "echo addn-hosts=/etc/pihole/kube.$${uuid}.list > /etc/dnsmasq.d/03-kube.conf"; \
		kubectl exec $${line} -- pihole restartdns; \
		echo >&2 "Reloaded DNS in node $${line}"; \
	done


.PHONY: killall
killall: $(foreach s,$(KUBERNETES_SERVICES), kill-$(s))


# Shutdown any service.
.PHONY: kill-%
kill-%:
	@kubectl scale deployment $*-deployment --replicas=0


# Restart any service.
# Currently makes the assumption that 1 replica is needed; could be upgraded to
#   check current scale.
.PHONY: restart-%
restart-%: kill-%
	@kubectl scale deployment $*-deployment --replicas=1


.PHONY: %-shell
%-shell:
	$(call KUBECTL_APP_EXEC,$*) -it -- sh


.PHONY: mysql-root-shell
mysql-root-shell:
	source .env && \
	$(call KUBECTL_APP_EXEC,mysql) -it -- \
		sh -c "mysql -uroot -p$${MYSQL_ROOT_PASSWORD}"


# Cycle all pods in the cluster. Really should only be used in weird debugging
#   situations.
.PHONY: refresh
refresh:
	$(foreach s,$(KUBERNETES_SERVICES),$(MAKE) restart-$(s);)


.PHONY: mongodb
mongodb:
	@kubectl create configmap mongodb-backup --from-file mongodb/mongodb-backup.sh -o yaml --dry-run | \
		kubectl apply -f -

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -
	@kubectl apply -f mongodb/mongodb-backup.yaml


.PHONY: registry
registry:
	@source .env && \
		kubectl create secret generic registry-htpasswd-secret \
			--from-literal "htpasswd=$$(htpasswd -nbB -C 10 $${DOCKER_REGISTRY_USERNAME} $${DOCKER_REGISTRY_PASSWORD})" -o yaml --dry-run | \
		kubectl apply -f -
	# Create the registry secret in the default and monitoring namespaces
	@source .env && \
		kubectl create secret docker-registry $(REGISTRY_HOSTNAME) \
			--docker-server $(REGISTRY_HOSTNAME) \
			--docker-username $${DOCKER_REGISTRY_USERNAME} \
			--docker-password $${DOCKER_REGISTRY_PASSWORD} -o yaml --dry-run | \
		kubectl apply -f -
	@source .env && \
		kubectl create secret -n monitoring docker-registry $(REGISTRY_HOSTNAME) \
			--docker-server $(REGISTRY_HOSTNAME) \
			--docker-username $${DOCKER_REGISTRY_USERNAME} \
			--docker-password $${DOCKER_REGISTRY_PASSWORD} -o yaml --dry-run | \
		kubectl apply -f -

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -

	@# Wait for the current registry to possibly be scheduled away if it needs
	@#   to be.
	@# This can probably be replaced with something more fancy at some point,
	@#   but it does what it needs to for now.
	@sleep 5

	@$(call KUBECTL_WAIT_FOR_POD,$@)

	@source .env && \
		$(DOCKER) login \
			--username $${DOCKER_REGISTRY_USERNAME}\
			--password $${DOCKER_REGISTRY_PASSWORD} \
			$(REGISTRY_HOSTNAME)


.PHONY: mysql
mysql:
	@source .env && \
		kubectl create secret generic mysql-root-password \
			--from-literal "value=$${MYSQL_ROOT_PASSWORD}" -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl apply -f mysql/mysql-volumes.yaml

	@kubectl create configmap mysql-backup --from-file mysql/mysql-backup.sh -o yaml --dry-run | \
		kubectl apply -f -

	@# Only tear everything down and run mysql-init if the existing service
	@#   can't be reached for any reason.
	@# There may be no pods running mysql at all, or there may be issues
	@#   actually running queries against it.
	@if [ -z "$$($(call KUBECTL_APP_PODS,mysql))" ] || \
			! $(call KUBECTL_APP_EXEC,mysql) -- sh -c "MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql -e 'SELECT 1'"; then \
		kubectl scale statefulset mysql --replicas=0; \
		kubectl scale statefulset mysql-init --replicas=0; \
		kubectl apply -f mysql/mysql-init.yaml; \
		while [ -z "$$($(call KUBECTL_RUNNING_POD,mysql-init))" ]; do \
			echo >&2 "MySQL pod not up yet. Waiting 1 second..."; \
			sleep 1; \
		done; \
		source .env && while ! $(call KUBECTL_APP_EXEC,mysql-init) -- mysql -e 'select 1;'; do \
			echo >&2 "MySQL service not up yet. Waiting 1 second..."; \
			sleep 1; \
		done; \
		source .env && $(call KUBECTL_APP_EXEC,mysql-init) -- \
			mysql -e '\
				FLUSH PRIVILEGES; \
				SET PASSWORD FOR root@localhost = PASSWORD("'$${MYSQL_ROOT_PASSWORD}'"); \
				CREATE USER IF NOT EXISTS '"'"'root'"'"'@'"'"'10.244.%.%'"'"'; \
				SET PASSWORD FOR '"'"'root'"'"'@'"'"'10.244.%.%'"'"' = PASSWORD("'$${MYSQL_ROOT_PASSWORD}'"); \
				GRANT ALL PRIVILEGES ON *.* to '"'"'root'"'"'@'"'"'10.244.%.%'"'"' WITH GRANT OPTION; \
				FLUSH PRIVILEGES;'; \
		kubectl scale statefulset mysql-init --replicas=0; \
	fi

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -
	@kubectl apply -f mysql/mysql-backup.yaml

.PHONY: firefly
firefly:
	@$(call KUBECTL_JOBS,firefly-mysql-init) | xargs kubectl delete

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

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


# Assumes that remindmebot has already shipped an image of its own to the
#   registry.
.PHONY: remindmebot
remindmebot:
	@$(call KUBECTL_JOBS,remindmebot-init) | xargs kubectl delete

	@source .env && \
		kubectl create configmap remindmebot-config \
			--from-literal "bot_username=$${REMINDMEBOT_USERNAME}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic remindmebot-secrets \
			--from-literal "bot_api_key=$${REMINDMEBOT_API_KEY}" \
			--from-literal "database=$${REMINDMEBOT_DATABASE}" \
			-o yaml --dry-run | kubectl apply -f -

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


.PHONY: openvpnas
openvpnas:
	@source .env && \
		kubectl create configmap openvpn-config \
			--from-literal "username=$${OPENVPN_PRIMARY_USERNAME}" \
			--from-literal "hostname=$${OPENVPN_AS_HOSTNAME}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic openvpn-password \
			--from-literal "value=$${OPENVPN_PRIMARY_USERPASS}" \
			-o yaml --dry-run | kubectl apply -f -

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -

	@# Wait a while in case a pod was already running, let it die, so we don't
	@#   try to run the setup script in the dying pod.
	@sleep 5

	@$(call KUBECTL_WAIT_FOR_POD,$@)
	@$(call KUBECTL_APP_EXEC,$@) -- sh -c 'set -ex; find scripts -type f | sort | while read line; do sh $$line; done'


# Configuration Recipes
.PHONY: nginx-configurations
nginx-configurations: networking 00-upstream.http.conf
	@kubectl create configmap nginx-config --from-file nginx.conf -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl create configmap nginx-servers-internal \
		--from-file 00-upstream.http.conf \
		--from-file nginx-internal/internal.http.conf \
		-o yaml --dry-run | kubectl apply -f -

	@kubectl create configmap nginx-servers-external \
		--from-file 00-upstream.http.conf \
		--from-file nginx-external/external.http.conf \
		-o yaml --dry-run | kubectl apply -f -


.PHONY: util-configurations
util-configurations:
	@source .env && \
		kubectl create configmap multi-reddit-blob-config \
			--from-literal "subreddit_path=$${MULTI_REDDIT_SUBS_LOCATION}" \
			--from-literal "saved_posts_path=$${MULTI_REDDIT_SAVED_LOCATION}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic multi-reddit-blob-credentials \
			--from-literal "read_acl=$${DEFAULT_BLOBSTORE_READ_ACL}" \
			--from-literal "write_acl=$${DEFAULT_BLOBSTORE_WRITE_ACL}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: resilio-configurations
resilio-configurations:
	@source .env && \
		kubectl create configmap resilio-sync-config \
			--from-literal "username=$${RESILIO_SERVER_USERNAME}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic resilio-sync-credentials \
			--from-literal "password=$${RESILIO_SERVER_PASSWORD}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: pihole-configurations
pihole-configurations: kube.list
	@kubectl create configmap pihole-config \
		--from-file pihole/setupVars.conf \
		--from-file kube.list \
		-o yaml --dry-run | kubectl apply -f -


.PHONY: slackbot-configurations
slackbot-configurations:
	@source .env && \
		kubectl create configmap slack-bot-config \
			--from-literal "default_channel=$${SLACK_BOT_DEFAULT_CHANNEL}" \
			--from-literal "alerting_channel=$${SLACK_BOT_ALERTING_CHANNEL}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create configmap -n monitoring slack-bot-config \
			--from-literal "default_channel=$${SLACK_BOT_DEFAULT_CHANNEL}" \
			--from-literal "alerting_channel=$${SLACK_BOT_ALERTING_CHANNEL}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic slack-bot-secrets \
			--from-literal "api_key=$${SLACK_BOT_API_KEY}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: blobstore-configurations
blobstore-configurations:
	@source .env && \
		kubectl create secret generic blobstore-secrets \
			--from-literal "database=$${BLOBSTORE_DATABASE}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: webcomics-configurations
webcomics-configurations:
	@source .env && \
		kubectl create secret generic webcomics-secrets \
			--from-literal "database=$${WEBCOMICS_DATABASE}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: certbot-configurations
certbot-configurations:
	@kubectl create secret generic internal-certificate-file 2> /dev/null || true
	@kubectl create secret generic internal-certificate-files 2> /dev/null || true
	@kubectl create secret generic external-certificate-file 2> /dev/null || true
	@kubectl create secret generic external-certificate-files 2> /dev/null || true
	@kubectl create configmap certbot-scripts \
		--from-file "certbot/dns-renew.sh" \
		--from-file "certbot/update-secrets.sh" \
		--from-file "certbot/patch.py" \
		-o yaml --dry-run | kubectl apply -f -


.PHONY: nodered-configurations
nodered-configurations:
	@source .env && \
		kubectl create configmap nodered-config \
			--from-literal "mysql_database=$${NODE_RED_MYSQL_DATABASE}" \
			--from-literal "mysql_user=$${NODE_RED_MYSQL_USER}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic nodered-secrets \
			--from-literal "mysql_password=$${NODE_RED_MYSQL_PASSWORD}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: tedbot-configurations
tedbot-configurations:
	@source .env && \
		kubectl create secret generic tedbot-webhook-url \
			--from-literal "value=$${SLACK_TEDBOT_APP_WEBHOOK}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: postgres-configurations
postgres-configurations:
	@source .env && kubectl create secret generic postgres-root-password \
		--from-literal "value=$${PG_PASSWORD}" \
		-o yaml --dry-run | kubectl apply -f -


.PHONY: guacamole-configurations
guacamole-configurations:
	@# Don't delete the init job, since it's not re-run safe.
	@# @$(call KUBECTL_JOBS,guacamole-mysql-init) | xargs kubectl delete
	@#
	@source .env && \
		kubectl create configmap guacamole-config \
			--from-literal "mysql_database=$${GUACAMOLE_DB}" \
			--from-literal "mysql_user=$${GUACAMOLE_DB_USER}" \
			-o yaml --dry-run | kubectl apply -f -

	@source .env && \
		kubectl create secret generic guacamole-secrets \
			--from-literal "database=mysql://$${GUACAMOLE_DB_USER}:$${GUACAMOLE_DB_PASSWORD}@mysql/$${GUACAMOLE_DB}" \
			--from-literal "mysql_password=$${GUACAMOLE_DB_PASSWORD}" \
			-o yaml --dry-run | kubectl apply -f -


.PHONY: mysql-restore
mysql-restore:
	@if [ -z "$${RESTORE_MYSQL_DATABASE}" ]; then \
		echo >&2 "Must supply RESTORE_MYSQL_DATABASE to target restore operation."; \
		exit 1; \
	fi

	@$(call KUBECTL_APP_EXEC,mysql) -- \
		sh -c "MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql -u root -e 'CREATE DATABASE IF NOT EXISTS '$${RESTORE_MYSQL_DATABASE}';'"

	@sed \
		-e 's/$${RESTORE_MYSQL_DATABASE}/'$${RESTORE_MYSQL_DATABASE}'/g' \
		 mysql/mysql-restore.yaml | kubectl apply -f -


.PHONY: mongodb-restore
mongodb-restore:
	@if [ -z "$${RESTORE_MONGODB_DATABASE}" ]; then \
		echo >&2 "Must supply RESTORE_MONGODB_DATABASE to target restore operation."; \
		exit 1; \
	fi

	@sed \
		-e 's/$${RESTORE_MONGODB_DATABASE}/'$${RESTORE_MONGODB_DATABASE}'/g' \
		 mongodb/mongodb-restore.yaml | kubectl apply -f -


.PHONY: unifi-restore
unifi-restore:
	@if [ ! -f backup.unf ]; then \
		echo >&2 "Can't find backup.unf. Aborting"; \
		exit 1; \
	fi

	kubectl scale deployment unifi-deployment --replicas=0
	kubectl apply -f unifi/unifi-restore.yaml

	$(call KUBECTL_WAIT_FOR_POD,unifi-restore)

	kubectl cp backup.unf $$($(call KUBECTL_APP_PODS,unifi-restore) | head -1):/backup.unf
	$(call KUBECTL_APP_EXEC,unifi-restore) -it -- java -Xmx1024M -jar /usr/lib/unifi/lib/ace.jar restore /backup.unf

	kubectl scale deployment unifi-restore --replicas=0
	kubectl scale deployment unifi-deployment --replicas=1


.PHONY: mysql-db-shell
mysql-db-shell:
	@source .env && $(call KUBECTL_APP_EXEC,mysql) -it -- \
		sh -c 'MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql'


$(KUBECONFIG):
	@mkdir -p $(@D)
	@ssh -t util1 "kubectl config view --raw" | sed 's/127.0.0.1/$(KUBERNETES_MASTER)/' > $@
	@cp $@ ~/.kube/config


.INTERMEDIATE: dns.vbash
dns.vbash:
	sed \
		-e 's/$${PIHOLE_IP}/'$(call SERVICE_LB_IP,pihole)'/' \
		.scripts/router-dns.vbash > $@


.PHONY: router-dns-config
router-dns-config: dns.vbash
	scp dns.vbash $(ROUTER_HOST_USER):temp.vbash
	ssh $(ROUTER_HOST_USER) /bin/vbash temp.vbash
	ssh $(ROUTER_HOST_USER) rm temp.vbash


.INTERMEDIATE: pf.vbash
pf.vbash:
	sed \
		-e 's/$${FACTORIO_IP}/'$(call SERVICE_LB_IP,factorio)'/' \
		-e 's/$${PLEX_IP}/'$(call SERVICE_LB_IP,plex)'/' \
		-e 's/$${OPENVPNAS_IP}/'$(call SERVICE_LB_IP,openvpnas)'/' \
		-e 's/$${NGINX_IP}/'$(call SERVICE_LB_IP,nginx-external)'/' \
		.scripts/router-port-forward.vbash > $@


# Port forwarding is all pretty custom, so don't bother trying to put any real
#   automation around this.
# This will destroy whatever existing port-forwarding rules exist too, so
#   hopefully they don't matter.
.PHONY: router-port-forwarding
router-port-forwarding: networking pf.vbash
	scp pf.vbash $(ROUTER_HOST_USER):temp.vbash
	ssh $(ROUTER_HOST_USER) /bin/vbash temp.vbash
	ssh $(ROUTER_HOST_USER) rm temp.vbash


.PHONY: ap-config
ap-config:
	@# Use the IP of the service, rather than the domain.
	@# The domain will point at nginx, so it'll be useless.
	@inform_ip=$$(kubectl get configmap network-ip-assignments -o template='{{index .data "unifi"}}') && \
	$(foreach ip,$(AP_IPS),ssh $(ip) mca-cli-op set-inform http://$${inform_ip}:8080/inform && ) \
	echo "Done"


.PHONY: token
token:
	@kubectl -n kube-system get secret $$(kubectl -n kube-system get serviceaccount aleem -o jsonpath={.secrets[0].name}) -o jsonpath={.data.token} | base64 -D && echo


# kube.list creates a pi-hole list that provides the appropriate ip addresses
#   when DNS requests are sent for internal services.
# This could probably be done better, considering the hard coding, but it works
.INTERMEDIATE: kube.list
kube.list:
	@nginx_lb_ip=$$(kubectl get configmap network-ip-assignments -o template='{{ index .data "nginx-internal" }}') && \
	http_services=$$(kubectl get configmap http-services -o template={{.data.default}}) && \
	arr=($(KUBERNETES_SERVICES)) && \
	for svc in "$${arr[@]}"; do \
		if echo $${http_services} | grep -q $${svc}; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		elif [ "$${svc}" == "grafana" ]; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		elif [ "$${svc}" == "alertmanager" ]; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		elif [ "$${svc}" == "dashboard" ]; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		elif [ "$${svc}" == "amproxy" ] || [ "$${svc}" == "tedbot" ]; then \
			continue; \
		else \
			printf '%s\t%s\t%s\n' \
				$$(kubectl get configmap network-ip-assignments -o template='{{ index .data "'$${svc}'" }}') \
				$$svc.$(NETWORK_SEARCH_DOMAIN). \
				$$svc >> $@; \
		fi; \
	done


# Base image is needed for several containers. Make sure that it's available
#   before any attempt at building other containers, or else docker will try to
#   pull an image called `ncfgbase`, and it won't find one.
# Try pulling the image first, because it very well already be up to date;
#   don't try to rebuild the image if other images have been built off another
#   ncfgbase
.PHONY: base-image
base-image:
	$(DOCKER) pull $(REGISTRY_HOSTNAME)/ncfgbase:latest
	$(DOCKER) build . -f BaseUpdatedUbuntuDockerfile -t ncfgbase
	$(DOCKER) tag ncfgbase $(REGISTRY_HOSTNAME)/ncfgbase:latest
	$(DOCKER) push $(REGISTRY_HOSTNAME)/ncfgbase:latest


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

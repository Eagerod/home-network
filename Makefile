SHELL=/bin/bash

# Figure out how this machine does docker:
ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
DOCKER:=eval $$(docker-machine env $$(docker-machine ls -q)) && docker
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

# Constants and calculated values
KUBERNETES_MASTER:=192.168.2.10
KUBERNETES_HOSTS:=$(shell kubectl get nodes -o jsonpath={.items[*].status.addresses[?\(@.type==\"InternalIP\"\)].address})
KUBERNETES_PROMETHEUS_VERISON=0.1.0

NETWORK_SEARCH_DOMAIN=internal.aleemhaji.com

KUBECONFIG=.kube/config

# COMPLEX_SERVICES are the set of services that require more than just a simple
#   template rule to be run.
COMPLEX_SERVICES= \
	mongodb \
	mysql \
	firefly \
	registry \
	remindmebot


# TRIVIAL_SERVICES are the set of services that are deployed by only applying
#   their yaml files.
TRIVIAL_SERVICES:=\
	redis \
	grafana \
	certbot \
	nginx \
	pihole \
	plex \
	sharelatex

# SIMPLE_SERVICES are the set of services that are deployed by creating a
#   docker image using the Dockerfile in the service's directory, and pushing
#   it to the container registry before applying its yaml file.
SIMPLE_SERVICES:=\
	trilium \
	factorio \
	transmission \
	unifi \
	util \
	resilio \
	slackbot

KUBERNETES_SERVICES=$(COMPLEX_SERVICES) $(TRIVIAL_SERVICES) $(SIMPLE_SERVICES)

# Some services are mostly just basic services, but require an additional
#   configuration to be pushed before they can properly start.
# Those services are included above, and additional prerequisites are listed
#   here.
nginx: nginx-configurations
util: util-configurations
pihole: pihole-configurations
resilio: resilio-configurations
slackbot: slackbot-configurations

REGISTRY_HOSTNAME:=registry.internal.aleemhaji.com

SERVICE_LB_IP = $$(kubectl get configmap network-ip-assignments -o template="{{.data.$(1)}}")
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
	FIREFLY_MYSQL_DATABASE


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


.PHONY: crons
crons:
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/rsync:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/rsync:latest

	@kubectl apply -f crons/cronjobs.yaml

	@kubectl get configmap cronjobs -o go-template={{.data._keys}} | while read line; do \
		sh -c "$$(kubectl get configmap cronjobs -o template={{.data.$${line}}} | tr '\n' ' ') envsubst < crons/rsync-cron.yaml" | \
			kubectl apply -f -; \
	done


.PHONY: certificates
certificates: internal-certificates external-certificates


.PHONY: internal-certificates
internal-certificates: internal-domain.crt internal-domain.rsa.key internal-domain.key internal-keycert.pem
	@kubectl create secret generic internal-certificate-files \
		--from-file tls.crt=internal-domain.crt \
		--from-file tls.key=internal-domain.key \
		--from-file tls.rsa.key=internal-domain.rsa.key \
		-o yaml --dry-run | \
			kubectl apply -f -
	@kubectl create secret generic internal-certificate-file \
		--from-file keycert.pem=internal-keycert.pem \
		-o yaml --dry-run | \
			kubectl apply -f -


.PHONY: external-certificates
external-certificates: external-domain.crt external-domain.rsa.key external-domain.key external-keycert.pem
	@kubectl create secret generic external-certificate-files \
		--from-file tls.crt=external-domain.crt \
		--from-file tls.key=external-domain.key \
		--from-file tls.rsa.key=external-domain.rsa.key \
		-o yaml --dry-run | \
			kubectl apply -f -
	@kubectl create secret generic external-certificate-file \
		--from-file keycert.pem=external-keycert.pem \
		-o yaml --dry-run | \
			kubectl apply -f -


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


.PHONY: $(TRIVIAL_SERVICES)
$(TRIVIAL_SERVICES):
	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


.PHONY: $(SIMPLE_SERVICES)
$(SIMPLE_SERVICES):
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/$@:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/$@:latest

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


# Restart any service.
# Currently makes the assumption that 1 replica is needed; could be upgraded to
#   check current scale.
.PHONY: restart-%
restart-%:
	@kubectl scale deployment $*-deployment --replicas=0
	@kubectl scale deployment $*-deployment --replicas=1


.PHONY: mongodb
mongodb: internal-certificates
	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -
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

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -

	@source .env && \
		$(DOCKER) login \
			--username $${DOCKER_REGISTRY_USERNAME}\
			--password $${DOCKER_REGISTRY_PASSWORD} \
			$(REGISTRY_HOSTNAME)


.PHONY: mysql
mysql: internal-certificates
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
		kubectl scale deployment mysql-deployment --replicas=0; \
		kubectl scale deployment mysql-init-deployment --replicas=0; \
		kubectl apply -f mysql/mysql-init.yaml; \
		while [ -z "$$($(call KUBECTL_RUNNING_POD,mysql-init))" ]; do \
			echo >&2 "MySQL not up yet. Waiting 1 second..."; \
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
		kubectl scale deployment mysql-init-deployment --replicas=0; \
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


# Configuration Recipes
.PHONY: nginx-configurations
nginx-configurations: networking 00-upstream.http.conf certificates
	@kubectl create configmap nginx-config --from-file nginx/nginx.conf -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl create configmap nginx-servers \
		--from-file 00-upstream.http.conf \
		--from-file nginx/internal.http.conf \
		--from-file nginx/internal.stream.conf \
		--from-file nginx/external.http.conf \
		--from-file nginx/external.stream.conf \
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
	kubectl create configmap pihole-config \
		--from-file pihole/setupVars.conf \
		--from-file kube.list \
		-o yaml --dry-run | kubectl apply -f -


.PHONY: slackbot-configurations
slackbot-configurations:
	@source .env && \
		kubectl create configmap slack-bot-config \
			--from-literal "default_channel=$${SLACK_BOT_DEFAULT_CHANNEL}" \
			-o yaml --dry-run | kubectl apply -f -
	@source .env && \
		kubectl create secret generic slack-bot-secrets \
			--from-literal "api_key=$${SLACK_BOT_API_KEY}" \
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


.PHONY: mysql-shell
mysql-shell:
	@source .env && $(call KUBECTL_APP_EXEC,mysql) -it -- \
		sh -c 'MYSQL_PWD=$${MYSQL_ROOT_PASSWORD} mysql'


$(KUBECONFIG):
	@mkdir -p $(@D)
	@ssh -t util1 "kubectl config view --raw" | sed 's/127.0.0.1/$(KUBERNETES_MASTER)/' > $@
	@cp $@ ~/.kube/config


.PHONY: router-bgp-config
router-bgp-config:
	ssh ubnt@192.168.1.1 /bin/vbash -c "'\
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols bgp 64512 parameters router-id 192.168.1.1; \
		$(foreach ip,$(KUBERNETES_HOSTS),/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols bgp 64512 neighbor $(ip) remote-as 64512;) \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set protocols bgp 64512 maximum-paths ibgp 64; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper save; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end; \
	'"


.PHONY: router-dns-config
router-dns-config:
	pihole_ip=$$(kubectl get configmap network-ip-assignments -o template={{.data.pihole}}) && \
	ssh ubnt@192.168.1.1 /bin/vbash -c "'\
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper begin; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding cache-size 0; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete system name-server; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set system name-server 127.0.0.1; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dhcp-server use-dnsmasq enable; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set interfaces ethernet eth0 dhcp-options name-server no-update; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding options strict-order; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper delete service dns forwarding name-server; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding name-server 8.8.4.4; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding name-server 8.8.8.8; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper set service dns forwarding name-server '$${pihole_ip}'; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper commit; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper save; \
		/opt/vyatta/sbin/vyatta-cfg-cmd-wrapper end; \
	'"


.PHONY: token
token:
	@kubectl -n kube-system get secret $$(kubectl -n kube-system get serviceaccount aleem -o jsonpath={.secrets[0].name}) -o jsonpath={.data.token} | base64 -D && echo


.INTERMEDIATE: internal-domain.crt
internal-domain.crt:
	@kubectl cp $$($(call KUBECTL_APP_PODS,certbot) | head -1):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/fullchain1.pem $@


.INTERMEDIATE: internal-domain.key
internal-domain.key:
	@kubectl cp $$($(call KUBECTL_APP_PODS,certbot) | head -1):/etc/letsencrypt/archive/internal.aleemhaji.com-0001/privkey1.pem $@


.INTERMEDIATE: external-domain.crt
external-domain.crt:
	@kubectl cp $$($(call KUBECTL_APP_PODS,certbot) | head -1):/etc/letsencrypt/archive/aleemhaji.com-0001/fullchain1.pem $@


.INTERMEDIATE: external-domain.key
external-domain.key:
	@kubectl cp $$($(call KUBECTL_APP_PODS,certbot) | head -1):/etc/letsencrypt/archive/aleemhaji.com-0001/privkey1.pem $@


.INTERMEDIATE: internal-domain.rsa.key
internal-domain.rsa.key: internal-domain.key
	openssl rsa -in $^ -out $@


.INTERMEDIATE: internal-keycert.pem
internal-keycert.pem: internal-domain.key internal-domain.crt
	@cat $^ > $@


.INTERMEDIATE: external-domain.rsa.key
external-domain.rsa.key: external-domain.key
	openssl rsa -in $^ -out $@


.INTERMEDIATE: external-keycert.pem
external-keycert.pem: external-domain.key external-domain.crt
	@cat $^ > $@


# kube.list creates a pi-hole list that provides the appropriate ip addresses
#   when DNS requests are sent for internal services.
# This could probably be done better, considering the hard coding, but it works
.INTERMEDIATE: kube.list
kube.list:
	@nginx_lb_ip=$$(kubectl get service nginx -o template={{.spec.loadBalancerIP}}) && \
	http_services=$$(kubectl get configmap http-services -o template={{.data.default}}) && \
	arr=($(KUBERNETES_SERVICES)) && \
	for svc in "$${arr[@]}"; do \
		if echo $${http_services} | grep -q $${svc}; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		elif [ "$${svc}" == "grafana" ]; then \
			printf '%s\t%s\t%s\n' $$nginx_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		else \
			printf '%s\t%s\t%s\n' \
				$$(kubectl get service $${svc} -o template={{.spec.loadBalancerIP}}) \
				$$svc.$(NETWORK_SEARCH_DOMAIN). \
				$$svc >> $@; \
		fi; \
	done


.PHONY: setup
setup: $(SETUP_FILES)


# Base image is needed for several containers. Make sure that it's available
#   before any attempt at building other containers, or else docker will try to
#   pull an image called `ncfgbase`, and it won't find one.
.PHONY: base-image
base-image:
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

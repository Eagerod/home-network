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

ROUTER_HOST:=192.168.1.1
ROUTER_HOST_USER:=ubnt@$(ROUTER_HOST)

# Constants and calculated values
KUBERNETES_PROMETHEUS_VERISON=0.1.0

AP_IPS=\
	192.168.1.43 \
	192.168.1.46 \
	192.168.1.56

NETWORK_SEARCH_DOMAIN=internal.aleemhaji.com

KUBECONFIG=.kube/config

# TRIVIAL_SERVICES are the set of services that are deployed by only applying
#   their yaml files.
TRIVIAL_SERVICES:=\
	grafana \
	certbot \
	nginx-external \
	pihole \
	plex \
	blobstore \
	webcomics \
	gitea


# SIMPLE_SERVICES are the set of services that are deployed by creating a
#   docker image using the Dockerfile in the service's directory, and pushing
#   it to the container registry before applying its yaml file.
SIMPLE_SERVICES:=\
	factorio \
	transmission \
	unifi \
	util


KUBERNETES_SERVICES=$(TRIVIAL_SERVICES) $(SIMPLE_SERVICES)

# Some services are mostly just basic services, but require an additional
#   configuration to be pushed before they can properly start.
# Those services are included above, and additional prerequisites are listed
#   here.
nginx-external: nginx-configurations
util: util-configurations
pihole: pihole-configurations
blobstore: blobstore-configurations
webcomics: webcomics-configurations
certbot: certbot-configurations

REGISTRY_HOSTNAME:=registry.internal.aleemhaji.com

SERVICE_LB_IP = $$(kubectl get configmap network-ip-assignments -o template='{{index .data "$(1)"}}')
REPLACE_LB_IP = sed "s/loadBalancerIP:.*/loadBalancerIP: $(call SERVICE_LB_IP,$(1))/" $(1)/$(1).yaml

KUBECTL_APP_PODS = kubectl get pods -l 'app=$(1)' -o name | sed 's:^pod/::'
KUBECTL_RUNNING_POD = kubectl get pods --field-selector=status.phase=Running -l 'app=$(1)' -o name | sed 's:^pod/::'
KUBECTL_APP_EXEC = kubectl exec $$($(call KUBECTL_RUNNING_POD,$(1)))

KUBECTL_WAIT_FOR_POD = while [ -z "$$($(call KUBECTL_RUNNING_POD,$(1)))" ]; do echo >&2 "$(1) not up yet. Waiting 1 second..."; sleep 1; done

# List of environment variables in projects that shouldn't be treated as secret.
SAVE_ENV_VARS=\
	MYSQL_USER\
	MYSQL_DATABASE\
	FF_APP_ENV\
	ADVERTISE_IP\
	DOCKER_REGISTRY_USERNAME\
	NODE_RED_MYSQL_USER\
	NODE_RED_MYSQL_DATABASE\
	OPENVPN_PRIMARY_USERNAME\
	OPENVPN_AS_HOSTNAME


.PHONY: all
all: initialize-cluster $(KUBERNETES_SERVICES)


.PHONY: services
services: $(KUBERNETES_SERVICES)


.PHONY: initialize-cluster
initialize-cluster:
	hope --config hope.yaml deploy

	@kubectl apply -f metrics-server.yaml

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
crons: base-image
	@$(DOCKER) pull $(REGISTRY_HOSTNAME)/rsync:latest
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/rsync:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/rsync:latest

	@kubectl apply -f crons/rsync-jobs.yaml

	@kubectl get configmap cronjobs -o go-template={{.data._keys}} | while read line; do \
		sh -c "$$(kubectl get configmap cronjobs -o template={{.data.$${line}}} | tr '\n' ' ') envsubst < crons/rsync-cron.yaml" | \
			kubectl apply -f -; \
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
complete-%: networking % reload-pihole


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


# Cycle all pods in the cluster. Really should only be used in weird debugging
#   situations.
.PHONY: refresh
refresh:
	$(foreach s,$(KUBERNETES_SERVICES),$(MAKE) restart-$(s);)


# Configuration Recipes
.PHONY: nginx-configurations
nginx-configurations: networking
	@kubectl create configmap nginx-config --from-file nginx.conf -o yaml --dry-run | \
		kubectl apply -f -

	@kubectl create configmap nginx-servers-external \
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


.PHONY: pihole-configurations
pihole-configurations: kube.list
	@kubectl create configmap pihole-config \
		--from-file pihole/setupVars.conf \
		--from-file kube.list \
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
		--from-file "certbot/update-secrets-default.sh" \
		--from-file "certbot/patch.py" \
		-o yaml --dry-run | kubectl apply -f -

	@kubectl create secret generic -n kube-system internal-certificate-file 2> /dev/null || true
	@kubectl create secret generic -n kube-system internal-certificate-files 2> /dev/null || true
	@kubectl create configmap certbot-scripts -n kube-system \
		--from-file "certbot/dns-renew.sh" \
		--from-file "certbot/update-secrets-kube-system.sh" \
		--from-file "certbot/patch.py" \
		-o yaml --dry-run | kubectl apply -f -

	@kubectl create secret generic -n monitoring internal-certificate-file 2> /dev/null || true
	@kubectl create secret generic -n monitoring internal-certificate-files 2> /dev/null || true
	@kubectl create configmap certbot-scripts -n monitoring \
		--from-file "certbot/dns-renew.sh" \
		--from-file "certbot/update-secrets-monitoring.sh" \
		--from-file "certbot/patch.py" \
		-o yaml --dry-run | kubectl apply -f -


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


$(KUBECONFIG):
	hope --config hope.yaml kubeconfig


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
	hope --config hope.yaml token aleem


# kube.list creates a pi-hole list that provides the appropriate ip addresses
#   when DNS requests are sent for internal services.
# This could probably be done better, considering the hard coding, but it works
.INTERMEDIATE: kube.list
kube.list: networking
	@ingress_lb_ip="$$(kubectl get configmap network-ip-assignments -o template='{{ index .data "ingress" }}')" && \
	ingress_services="$$(kubectl get configmap http-services -o template={{.data.ingress}})" && \
	arr=($(KUBERNETES_SERVICES)) && \
	for svc in "$${arr[@]}"; do \
		if echo "$${ingress_services}" | grep -q "^$${svc}$$\|^$${svc}-tcp$$"; then \
			printf '%s\t%s\t%s\n' $$ingress_lb_ip $$svc.$(NETWORK_SEARCH_DOMAIN). $$svc >> $@; \
		else \
			printf '%s\t%s\t%s\n' \
				$$(kubectl get configmap network-ip-assignments -o template='{{ index .data "'$${svc}'" }}') \
				$$svc.$(NETWORK_SEARCH_DOMAIN). \
				$$svc >> $@; \
		fi; \
	done


.git/hooks/pre-push:
	# For whatever reason, this can choose to run despite the file already
	#   existing and having no dependencies. Possibly an issue with having a
	#   symlink as a target?
	ln -sf ${PWD}/.scripts/hooks/pre-push.sh $@


.gitignore-extra:
	@touch $@


.gitignore: Makefile .gitignore-extra
	@curl -fsSL https://www.toptal.com/developers/gitignore/api/vim,macos,linux,vscode,windows,intellij,sublimetext,git > $@
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

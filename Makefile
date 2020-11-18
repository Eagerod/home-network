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


# SIMPLE_SERVICES are the set of services that are deployed by creating a
#   docker image using the Dockerfile in the service's directory, and pushing
#   it to the container registry before applying its yaml file.
SIMPLE_SERVICES:=\
	unifi


KUBERNETES_SERVICES=$(SIMPLE_SERVICES)

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


.PHONY: $(SIMPLE_SERVICES)
$(SIMPLE_SERVICES):
	@$(DOCKER) pull $(REGISTRY_HOSTNAME)/$@:latest
	@$(DOCKER) build $@ -t $(REGISTRY_HOSTNAME)/$@:latest
	@$(DOCKER) push $(REGISTRY_HOSTNAME)/$@:latest

	@$(call REPLACE_LB_IP,$@) | kubectl apply -f -


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

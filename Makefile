SHELL=/bin/bash

ROUTER_HOST:=192.168.1.1
ROUTER_HOST_USER:=ubnt@$(ROUTER_HOST)

SERVICE_LB_IP = $$(kubectl get configmap network-ip-assignments -o template='{{index .data "$(1)"}}')

HOPE = hope --config hope.yaml
PACKER_IMAGES_DIR=/var/lib/packer/images

VM_SSH_HOST_KEYS=\
	/var/lib/packer/etc/ssh/ssh_host_dsa_key \
	/var/lib/packer/etc/ssh/ssh_host_ecdsa_key \
	/var/lib/packer/etc/ssh/ssh_host_ed25519_key \
	/var/lib/packer/etc/ssh/ssh_host_rsa_key

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
all: initialize-cluster

$(PACKER_IMAGES_DIR)/load-balancer/load-balancer.ovf: $(shell find vms/load-balancer -type f) $(VM_SSH_HOST_KEYS)
	$(HOPE) vm image --force beast1 load-balancer

$(PACKER_IMAGES_DIR)/kubernetes-node/kubernetes-node.ovf: $(shell find vms/kubernetes-node -type f) $(VM_SSH_HOST_KEYS)
	$(HOPE) vm image --force beast1 kubernetes-node

$(VM_SSH_HOST_KEYS):
	ssh-keygen -A -f /var/lib/packer

.PHONY: initialize-cluster
initialize-cluster:
	$(HOPE) deploy


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

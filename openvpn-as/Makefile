include ../docker.make

REQUIRED_ENV_VARS:=\
	SERVER_IP\
	SERVER_SUBNET_START\
	OPENVPN_PRIMARY_USERNAME\
	OPENVPN_PRIMARY_USERPASS

SACLI_PATH:=/usr/local/openvpn_as/scripts/sacli


setup: config


.PHONY: config
config:
	# Start up the openvpn server to copy configurations. Make sure it has time
	#   to populate its configs. Copy using a platform agnostic approach, even
	#   though it may be a little less efficient on Linux.
	$(MAKE) -C .. openvpn-as
	sleep 2

	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --key vpn.daemon.0.client.netmask_bits --value 24 ConfigPut
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --key vpn.daemon.0.listen.ip_address --value all ConfigPut

	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --key vpn.server.routing.private_network.0 --value $${SERVER_SUBNET_START}/24 ConfigPut
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --key vpn.daemon.0.client.network --value $${SERVER_SUBNET_START} ConfigPut
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --key host.name --value $${SERVER_IP} ConfigPut

	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --user $${OPENVPN_PRIMARY_USERNAME} --key "type" --value "user_connect" UserPropPut
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --user $${OPENVPN_PRIMARY_USERNAME} --key "prop_superuser" --value "true" UserPropPut
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --user $${OPENVPN_PRIMARY_USERNAME} --new_pass $${OPENVPN_PRIMARY_USERPASS} SetLocalPassword

	# Delete the admin user at the suggestion of linuxserver.io's dockerhub page
	#  https://hub.docker.com/r/linuxserver/openvpn-as/
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) --user admin UserPropDelAll || true
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) sed -i 's/^boot_pam_users.0=admin/# boot_pam_users.0=admin/' /config/etc/as.conf

	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH) Reset


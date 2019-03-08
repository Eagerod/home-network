include ../docker.make

REQUIRED_ENV_VARS:=\
	SERVER_IP\
	SERVER_SUBNET_START\
	OPENVPN_PRIMARY_USERNAME\
	OPENVPN_PRIMARY_USERPASS

SACLI_PATH:=/usr/local/openvpn_as/scripts/sacli
EXEC_SACLI:=$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH)


setup: config


.PHONY: config
config:
	@# Start up the openvpn server to copy configurations. Make sure it has time
	@#   to populate its configs. Copy using a platform agnostic approach, even
	@#   though it may be a little less efficient on Linux.
	$(MAKE) -C .. openvpn-as
	sleep 2

	$(EXEC_SACLI) --key vpn.daemon.0.client.network --value 172.27.224.0 ConfigPut
	$(EXEC_SACLI) --key vpn.daemon.0.client.netmask_bits --value 24 ConfigPut
	$(EXEC_SACLI) --key vpn.daemon.0.listen.ip_address --value all ConfigPut
	$(EXEC_SACLI) --key vpn.server.google_auth.enable --value true ConfigPut
	$(EXEC_SACLI) --key vpn.server.port_share.enable --value false ConfigPut
	$(EXEC_SACLI) --key vpn.server.port_share.service --value custom ConfigPut

	@# Host the client UI on a different port, so the client interface can be
	@#   exposed publicly without the admin interface.
	$(EXEC_SACLI) --key cs.https.port --value 944 ConfigPut
	$(EXEC_SACLI) --key cs.https.ip_address --value all ConfigPut

	source .env && $(EXEC_SACLI) --key vpn.server.routing.private_network.0 --value $${SERVER_SUBNET_START}/24 ConfigPut
	source .env && $(EXEC_SACLI) --key host.name --value $${SERVER_IP} ConfigPut

	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --key type --value user_connect UserPropPut
	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --key prop_superuser --value true UserPropPut
	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --new_pass $${OPENVPN_PRIMARY_USERPASS} SetLocalPassword

	@# Delete the admin user at the suggestion of linuxserver.io's dockerhub page
	@#  https://hub.docker.com/r/linuxserver/openvpn-as/
	source .env && $(EXEC_SACLI) --user admin UserPropDelAll || true
	source .env && $(EXEC_SACLI) --user openvpn UserPropDelAll || true
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) sed -i 's/^boot_pam_service=openvpnas/# boot_pam_service=openvpnas/' /config/etc/as.conf
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) sed -i 's/^boot_pam_users.0=admin/# boot_pam_users.0=admin/' /config/etc/as.conf
	
	source .env && if [ -z "$$($(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} UserPropGet | grep '"pvt_google_auth_secret"' | awk '{print $$2}' | tr -cd '[[:alnum:]]')" ]; then \
		$(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} GoogleAuthRegen; \
		$(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --lock 1 GoogleAuthLock; \
		\
		echo "User account has been created and password, and MFA have been set."; \
		echo "The user $${OPENVPN_PRIMARY_USERNAME}'s MFA code can be scanned here:"; \
		\
		$(MAKE) get-2fa; \
	fi

	$(EXEC_SACLI) Reset


.PHONY: get-2fa
get-2fa:
	@source .env && echo 'https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=otpauth%3A//totp/'$${OPENVPN_PRIMARY_USERNAME}'%2540OpenVPN%3Fsecret%3D'$$($(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} UserPropGet | grep '"pvt_google_auth_secret"' | awk '{print $$2}' | tr -cd '[[:alnum:]]')'&choe=UTF-8'

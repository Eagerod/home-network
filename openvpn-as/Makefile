include ../docker.make

REQUIRED_ENV_VARS:=\
	SERVER_IP\
	SERVER_SUBNET_START\
	OPENVPN_PRIMARY_USERNAME\
	OPENVPN_PRIMARY_USERPASS

SCRIPTS_PATH:=/usr/local/openvpn_as/scripts
SACLI_PATH:=$(SCRIPTS_PATH)/sacli
CERTOOL_PATH:=$(SCRIPTS_PATH)/certool
CERT_PATH:=/usr/local/openvpn_as/etc/web-ssl

EXEC_SACLI:=$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(SACLI_PATH)
CONFIG_FILE:=/config/etc/as.conf


setup: config


.PHONY: config
config:
	@# Start up the openvpn server to copy configurations.
	@# Make sure it has time to finishing its first start routine.
	$(MAKE) -C .. openvpn-as
	while ! $(EXEC_SACLI) status; do sleep 1; done

	$(EXEC_SACLI) --key vpn.server.google_auth.enable --value true ConfigPut
	$(EXEC_SACLI) --key vpn.server.port_share.enable --value false ConfigPut
	$(EXEC_SACLI) --key vpn.server.port_share.service --value custom ConfigPut

	@# Host the client UI on a different port, so the client interface can be
	@#   exposed publicly without the admin interface.
	$(EXEC_SACLI) --key cs.https.port --value 944 ConfigPut

	source .env && $(EXEC_SACLI) --key vpn.server.routing.private_network.0 --value $${SERVER_SUBNET_START}/24 ConfigPut
	source .env && $(EXEC_SACLI) --key host.name --value $${SERVER_IP} ConfigPut

	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --key type --value user_connect UserPropPut
	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --key prop_superuser --value true UserPropPut
	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --key prop_deny --value false UserPropPut
	source .env && $(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --new_pass $${OPENVPN_PRIMARY_USERPASS} SetLocalPassword

	$(EXEC_SACLI) --user __DEFAULT__ --key def_deny --value true UserPropPut
	$(EXEC_SACLI) --user __DEFAULT__ --key prop_deny --value true UserPropPut

	source .env && if [ -z "$$($(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} UserPropGet | grep '"pvt_google_auth_secret"' | awk '{print $$2}' | tr -cd '[[:alnum:]]')" ]; then \
		$(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} GoogleAuthRegen; \
		$(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} --lock 1 GoogleAuthLock; \
		\
		echo "User account has been created and password, and MFA have been set."; \
		echo "The user $${OPENVPN_PRIMARY_USERNAME}'s MFA code can be scanned here:"; \
		\
		$(MAKE) get-2fa; \
	fi

	@# The first time the container is started, it'll run a configuration init
	@#   script that sets up user accounts, and allows access to the VPN that
	@#   shouldn't exit. Remove those.
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) sed -i -r 's/^(boot_pam_service.*)/# \1/g' $(CONFIG_FILE)
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) sed -i -r 's/^(boot_pam_users.*)/# \1/g' $(CONFIG_FILE)

	source .env && $(DOCKER) exec -e pass=$${OPENVPN_PRIMARY_USERPASS} $(RUNNING_CONTAINER_NAME) bash -c 'echo "admin:$${pass}" | chpasswd'

	$(EXEC_SACLI) --user admin UserPropDelAll || true
	$(EXEC_SACLI) --user openvpn UserPropDelAll || true

	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) passwd -d openvpn

	@# Regenerate SSL Certs
	@# By default, these ship with the base image.
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(CERTOOL_PATH) -d $(CERT_PATH) --type ca --unique --cn "OpenVpn Aleem Home"
	source .env && $(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(CERTOOL_PATH) -d $(CERT_PATH) --type server --remove_csr --sn_off --serial 1 --name server --cn $${SERVER_IP}

	@# Killing the service seems to be the only reliable way to have all
	@#   configurations persist completely.
	$(EXEC_SACLI) Reset
	$(MAKE) kill


.PHONY: get-2fa
get-2fa:
	@source .env && echo 'https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=otpauth%3A//totp/'$${OPENVPN_PRIMARY_USERNAME}'%2540OpenVPN%3Fsecret%3D'$$($(EXEC_SACLI) --user $${OPENVPN_PRIMARY_USERNAME} UserPropGet | grep '"pvt_google_auth_secret"' | awk '{print $$2}' | tr -cd '[[:alnum:]]')'&choe=UTF-8'

include ../docker.make

REQUIRED_ENV_VARS:=\
	SERVER_IP\
	SERVER_SUBNET_START

setup: config


.PHONY: config
config:
	# Start up the openvpn server to copy configurations. Make sure it has time
	#   to populate its configs. Copy using a platform agnostic approach, even
	#   though it may be a little less efficient on Linux.
	$(MAKE) -C .. openvpn-as
	sleep 2

	$(DOCKER) cp $(RUNNING_CONTAINER_NAME):/config/etc/db/config.db ./config.db

	sqlite3 config.db 'update config set value=24 where profile_id=1 and name="vpn.daemon.0.client.netmask_bits";'
	sqlite3 config.db 'update config set value="all" where profile_id=1 and name="vpn.daemon.0.listen.ip_address";'

	source .env && sqlite3 config.db 'update config set value="'$${SERVER_SUBNET_START}'/24" where profile_id=1 and name="vpn.server.routing.private_network.0";'
	source .env && sqlite3 config.db 'update config set value="'$${SERVER_SUBNET_START}'" where profile_id=1 and name="vpn.daemon.0.client.network";'
	source .env && sqlite3 config.db 'update config set value="'$${SERVER_IP}'" where profile_id=1 and name="host.name";'

	$(DOCKER) cp ./config.db $(RUNNING_CONTAINER_NAME):/config/etc/db/config.db

	# Access Server will have to be restarted for changes to take effect.
	$(MAKE) kill
	rm config.db

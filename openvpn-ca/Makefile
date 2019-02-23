include ../docker.make

REQUIRED_ENV_VARS:=\
	KEY_COUNTRY \
	KEY_PROVINCE \
	KEY_CITY \
	KEY_ORG \
	KEY_EMAIL \
	KEY_OU

OPENVPN_CA_DIR:=/var/lib/openvpn-ca
OPENVPN_CA_VARS:=$(OPENVPN_CA_DIR)/vars

.PHONY: ca-certs
ca-certs:
	$(MAKE) -C .. debug/openvpn-ca

	# make-cadir refuses to create in a directory that already exists. Since
	#   this dir is mounted as a volume, gotta copy things over.
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) make-cadir $(OPENVPN_CA_DIR)-temp
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) bash -c 'cp -r $(OPENVPN_CA_DIR)-temp/* $(OPENVPN_CA_DIR)/'
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) rm -rf $(OPENVPN_CA_DIR)-temp

	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) bash -c 'printf "#!/usr/bin/env bash\nsource $(OPENVPN_CA_VARS)\n./build-ca --batch" > $(OPENVPN_CA_DIR)/sourcebuild-ca'
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) chmod 775 $(OPENVPN_CA_DIR)/sourcebuild-ca
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) bash -c 'printf "#!/usr/bin/env bash\nsource $(OPENVPN_CA_VARS)\n./build-dh --batch" > $(OPENVPN_CA_DIR)/sourcebuild-dh'
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) chmod 775 $(OPENVPN_CA_DIR)/sourcebuild-dh

	for i in $(REQUIRED_ENV_VARS); do \
		source .env && $(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) sed -i "s/$$i.*/$$i=\"$${!i}\"/" $(OPENVPN_CA_VARS); \
	done

	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) rm -rf openssl.cnf
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) ln openssl-1.0.0.cnf openssl.cnf
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) $(OPENVPN_CA_DIR)/sourcebuild-ca
	$(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) $(OPENVPN_CA_DIR)/sourcebuild-dh


.PHONY: delete-certs
delete-certs:
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) rm -rf $(OPENVPN_CA_DIR)-temp
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) rm -rf $(OPENVPN_CA_DIR)/*
	# $(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) bash -c 'printf "#!/usr/bin/env bash\nsource $(OPENVPN_CA_VARS)\n./clean-all" > $(OPENVPN_CA_DIR)/sourceclean'
	# $(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) chmod 775 $(OPENVPN_CA_DIR)/sourceclean
	# $(ATTACHED_DOCKER) exec -w $(OPENVPN_CA_DIR) -it $(RUNNING_CONTAINER_NAME) $(OPENVPN_CA_DIR)/sourceclean

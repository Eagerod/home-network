include ../docker.make


REQUIRED_ENV_VARS:=\
	SERVER_HOST_IP


setup: initialize

# Copy an existing UniFi Controller configuration file to a container running
#   the controller, and run the restore function.
.PHONY: initialize
initialize:
	source .env && if [ ! -f "$${UNIFI_CONFIGURATION_PATH}" ]; then \
		echo >&2 "Failed to find UniFi backup at $${UNIFI_CONFIGURATION_PATH}."; \
		echo >&2 "Use 'make wizard' to configure a new controller."; \
	else \
		DOCKER_COMPOSE_EXTRAS='-f unifi/build.yml' $(MAKE) -C .. $(DOCKER_IMAGE_NAME); \
		source .env && $(DOCKER) cp $${UNIFI_CONFIGURATION_PATH} $(RUNNING_CONTAINER_NAME):/backup.unf; \
		$(DOCKER) exec -it $(RUNNING_CONTAINER_NAME) java -Xmx1024M -jar /usr/lib/unifi/lib/ace.jar restore /backup.unf; \
		$(MAKE) kill; \
	fi


# If there's no configuration at all for this deployment, create a compose yml
#   file that will let the user go through the wizard process to create their
#   own config
.PHONY: wizard
wizard: wizard.yml
	DOCKER_COMPOSE_EXTRAS='-f unifi/wizard.yml' $(MAKE) -C .. $(DOCKER_IMAGE_NAME)

.INTERMEDIATE: wizard.yml
wizard.yml:
	printf "version: '3'\nservices:\n  unifi:\n    build:\n      args:\n        - IS_DEFAULT=true\n" > wizard.yml

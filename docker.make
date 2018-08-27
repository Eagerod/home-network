include $(dir $(realpath $(lastword $(MAKEFILE_LIST))))/common.make

SHELL=/bin/bash

DOCKER_BUILD_ARGS:=
DOCKER_IMAGE_NAME:=
DOCKER_PORT_FORWARDS:=

RUNNING_CONTAINER_NAME=$$($(DOCKER) ps | awk '{if ($$2 == "$(DOCKER_IMAGE_NAME)") print $$NF;}') 2> /dev/null

.PHONY: validate_build_args
validate_build_args:
	@$(foreach arg,$(DOCKER_BUILD_ARGS),\
		if [ -z "$${$(arg)}" ]; then \
			echo >&2 "Missing build environment variable $(arg)"; \
		 	exit -1; \
		fi; \
	)

.PHONY: validate_image_name
validate_image_name:
	@if [ -z "$(DOCKER_IMAGE_NAME)" ]; then \
		echo >&2 'No Docker image name specified. Please create a $$(DOCKER_IMAGE_NAME).'; \
		exit -1; \
	fi

.PHONY: base-image
base-image:
	$(DOCKER) build .. -f ../BaseUpdatedUbuntuDockerfile -t ncfgbase

.PHONY: image
image: validate_build_args validate_image_name base-image
	@if [ $(RUNNING_CONTAINER_NAME) ]; then \
		echo >&2 "Container is already running; creating image will delete old tag."; \
		exit -1; \
	fi
	$(DOCKER) build $(foreach arg,$(DOCKER_BUILD_ARGS),--build-arg $(arg)=$${$(arg)} ) . -t $(DOCKER_IMAGE_NAME)

.PHONY: detached
detached: image
	$(DOCKER) container run -dit $(DOCKER_PORT_FORWARDS) $(DOCKER_IMAGE_NAME)

.PHONY: attached
attached: image
	$(ATTACHED_DOCKER) container run $(DOCKER_PORT_FORWARDS) -it $(DOCKER_IMAGE_NAME)

.PHONY: debug
debug: kill
	$(SED_INLINE) 's/^CMD/# CMD/g' Dockerfile

.PHONY: release
release: kill
	$(SED_INLINE) 's/^# CMD/CMD/g' Dockerfile

.PHONY: kill
kill: validate_image_name
	$(DOCKER) kill $(RUNNING_CONTAINER_NAME) 2> /dev/null || true

.PHONY: shell
shell: validate_image_name
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) bash || echo "Failed to find container"

.PHONY: logs
logs:
	$(ATTACHED_DOCKER) logs -f $(RUNNING_CONTAINER_NAME)

DOCKER_IMAGE_NAME:=pi-hole
DOCKER_PORT_FORWARDS:=-p 80:80 -p 53:53/tcp -p 53:53/udp
DOCKER_BUILD_ARGS:=

.PHONY: image
image: validate_env
	docker build $(DOCKER_BUILD_ARGS) . -t $(DOCKER_IMAGE_NAME)

.PHONY: detached
detached:
	docker container run -d $(DOCKER_PORT_FORWARDS) $(DOCKER_IMAGE_NAME)

.PHONY: attached
attached:
	winpty docker container run $(DOCKER_PORT_FORWARDS) -it $(DOCKER_IMAGE_NAME)

.PHONY: debug
debug:
	sed -i 's/^CMD/# CMD/g' Dockerfile

.PHONY: release
release:
	sed -i 's/^# CMD/CMD/g' Dockerfile

.PHONY: validate_env
validate_env:

.PHONY: kill
kill:
	docker kill $$(docker ps | awk '{if ($$2 == "$(DOCKER_IMAGE_NAME)") print $$NF;}')


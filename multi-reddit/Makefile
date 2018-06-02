DOCKER_IMAGE_NAME:=multi-reddit
DOCKER_PORT_FORWARDS:=-p 22:22
DOCKER_BUILD_ARGS:=\
	--build-arg DEFAULT_BLOBSTORE_WRITE_ACL=$$DEFAULT_BLOBSTORE_WRITE_ACL \
	--build-arg DEFAULT_BLOBSTORE_READ_ACL=$$DEFAULT_BLOBSTORE_READ_ACL \
	--build-arg MULTI_REDDIT_SUBS_LOCATION=$$MULTI_REDDIT_SUBS_LOCATION \
	--build-arg MULTI_REDDIT_SAVED_LOCATION=$$MULTI_REDDIT_SAVED_LOCATION

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
	if [ -z "$${DEFAULT_BLOBSTORE_READ_ACL}" ]; then exit -1; fi
	if [ -z "$${DEFAULT_BLOBSTORE_WRITE_ACL}" ]; then exit -1; fi
	if [ -z "$${MULTI_REDDIT_SUBS_LOCATION}" ]; then exit -1; fi
	if [ -z "$${MULTI_REDDIT_SAVED_LOCATION}" ]; then exit -1; fi

.PHONY: kill
kill:
	docker kill $$(docker ps | awk '{if ($$2 == "$(DOCKER_IMAGE_NAME)") print $$NF;}')


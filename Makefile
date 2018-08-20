SHELL=/bin/bash

ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
else ifeq ($(shell sudo docker ps > /dev/null && echo "pass"),pass)
DOCKER:=sudo docker
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
$(error Cannot communicate with docker daemon. Maybe run `eval $$(docker-machine env $(shell docker-machine ls -q))`)
else
$(error Cannot communicate with docker daemon)
endif

DOCKER_CONTAINERS:=\
	multi-reddit \
	transmission-oss \
	mysql \
	firefly-iii \
	mongodb

.PHONY: all
all: $(DOCKER_CONTAINERS)

.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS):
	cd $@ && $(MAKE) kill || true
	cd $@ && if [[ -f ".env" ]]; then source $$(pwd)/.env; fi && $(MAKE) release image detached

.PHONY: kill
kill:
	@$(foreach container, $(DOCKER_CONTAINERS),\
		$(MAKE) -C $(CURDIR)/$(container) kill; \
	)

.PHONY: reset
reset: kill
	$(DOCKER) container rm $$($(DOCKER) container ls -aq) || true
	$(DOCKER) image rm $$($(DOCKER) image list -q) || true
	$(MAKE)

.PHONY: clean
clean:
	$(DOCKER) container prune -f
	$(DOCKER) image prune -f

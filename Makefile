DOCKER_CONTAINERS:=multi-reddit pi-hole transmission-oss mysql firefly-iii

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
	docker container rm $$(docker container ls -aq) || true
	docker image rm $$(docker image list -q) || true
	$(MAKE)

.PHONY: clean
clean:
	docker container prune -f
	docker image prune -f

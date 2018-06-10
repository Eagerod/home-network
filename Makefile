DOCKER_CONTAINERS:=multi-reddit pi-hole transmission-oss mysql

.PHONY: all
all: $(DOCKER_CONTAINERS)

.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS):
	cd $@ && $(MAKE) kill || true
	cd $@ && if [[ -f ".env" ]]; then source $$(pwd)/.env; fi && $(MAKE) release image detached

kill:
	@$(foreach container, $(DOCKER_CONTAINERS),\
		$(MAKE) -C $(CURDIR)/$(container) kill; \
	)

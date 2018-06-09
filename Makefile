DOCKER_CONTAINERS:=multi-reddit pi-hole transmission-oss mysql

.PHONY: all
all: $(DOCKER_CONTAINERS)

.PHONY: $(DOCKER_CONTAINERS)
$(DOCKER_CONTAINERS):
	cd $@ && make kill || true
	cd $@ && make release image detached


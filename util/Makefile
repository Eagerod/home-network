include ../DockerMakefile

DOCKER_IMAGE_NAME:=util
DOCKER_PORT_FORWARDS:=-p 22:22
DOCKER_BUILD_ARGS:=\
	DEFAULT_BLOBSTORE_WRITE_ACL \
	DEFAULT_BLOBSTORE_READ_ACL \
	MULTI_REDDIT_SUBS_LOCATION \
	MULTI_REDDIT_SAVED_LOCATION

ifeq ($(shell uname),Linux)
DOCKER_PORT_FORWARDS+=\
	-v /var/lib/backups:/var/lib/backups
else
DOCKER_PORT_FORWARDS+= \
	-v D:/DockerBackups:/var/lib/backups
endif


# Create an ssh key for the host machine that the container will accept
#   as an authorized_host
.PHONY: initialize
initialize:
	@if [ ! -f ~/.ssh/util-server ]; then \
		ssh-keygen -t rsa -b 4096 -C "com.haji.aleem.util/host" -f ~/.ssh/util-server; \
	else \
		echo >&2 "SSH key already present in for util server. Skipping key creation."; \
	fi
	@if [ -z "$$(cat authorized_keys | grep "$$(cat ~/.ssh/util-server.pub)")" ]; then \
		cat ~/.ssh/util-server.pub >> authorized_keys; \
	else \
		echo >&2 "SSH key already authorized for util server. Skipping addition to authorized_keys."; \
	fi
ifeq ($(shell uname),Linux)
	sudo mkdir -p /var/lib/backups
endif

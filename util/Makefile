include ../docker.make

# TODO: Create a host ssh server key that won't change when the util server is
#   restarted. This causes issues with the known_hosts file on clients, and
#   makes it pretty frustrating to deal with connections over time.

BACKUPS_CONTAINER_BACKUP_DIR:=/var/lib/backups

ifeq ($(PLATFORM),$(PLATFORM_MACOS))
BACKUPS_HOST_BACKUP_DIR:=~/Desktop/docker/backups
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
BACKUPS_HOST_BACKUP_DIR:=/var/lib/backups
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
BACKUPS_HOST_BACKUP_DIR:=D:/DockerBackups
endif

DOCKER_IMAGE_NAME:=util
DOCKER_PORT_FORWARDS:=\
	-p 22:22\
	-v $(BACKUPS_HOST_BACKUP_DIR):$(BACKUPS_CONTAINER_BACKUP_DIR)
DOCKER_BUILD_ARGS:=\
	DEFAULT_BLOBSTORE_WRITE_ACL \
	DEFAULT_BLOBSTORE_READ_ACL \
	MULTI_REDDIT_SUBS_LOCATION \
	MULTI_REDDIT_SAVED_LOCATION

HOST_SSH_KEY_PATH:=~/.ssh/util-server
HOST_SSH_KEY_COMMENT:=ca.haji.aleem.util/host

$(HOST_SSH_KEY_PATH):
	ssh-keygen -t rsa -b 4096 -C "$(HOST_SSH_KEY_COMMENT)" -f $(HOST_SSH_KEY_PATH)

# Create an ssh key for the host machine that the container will accept
#   as an authorized_host
.PHONY: initialize
initialize: $(HOST_SSH_KEY_PATH)
	@if ! grep -q -f $(HOST_SSH_KEY_PATH).pub authorized_keys ; then \
		cat $(HOST_SSH_KEY_PATH).pub >> authorized_keys; \
	else \
		echo >&2 "SSH key already authorized for util server. Skipping addition to authorized_keys."; \
	fi
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	sudo mkdir -p $(BACKUPS_HOST_BACKUP_DIR)
endif

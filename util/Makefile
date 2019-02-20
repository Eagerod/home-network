include ../docker.make

# TODO: Create a host ssh server key that won't change when the util server is
#   restarted. This causes issues with the known_hosts file on clients, and
#   makes it pretty frustrating to deal with connections over time.

BACKUPS_CONTAINER_BACKUP_DIR:=/var/lib/backups
BACKUPS_CONTAINER_GIT_DIR:=/var/lib/git

ifeq ($(PLATFORM),$(PLATFORM_MACOS))
BACKUPS_HOST_BACKUP_DIR:=~/Desktop/docker/backups
BACKUPS_HOST_GIT_DIR:=~/Desktop/docker/git
SUDO:=
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
BACKUPS_HOST_BACKUP_DIR:=/var/lib/backups
BACKUPS_HOST_GIT_DIR:=/var/lib/git
SUDO:=sudo
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
BACKUPS_HOST_BACKUP_DIR:=D:/DockerBackups
BACKUPS_HOST_GIT_DIR:=D:/DockerGit
SUDO:=
endif

HOST_REPO_REPO:=$(BACKUPS_HOST_GIT_DIR)/repositories.git

HOST_SSH_DIR:=~/.ssh
HOST_SSH_KEY_PATH:=$(HOST_SSH_DIR)/util-server
HOST_SSH_KEY_COMMENT:=ca.haji.aleem.util/host


CRON_SCHEDULE=@hourly


setup: initialize

# Create an ssh key for the host machine that the container will accept
#   as an authorized_host
.PHONY: initialize
initialize: $(HOST_SSH_KEY_PATH) $(HOST_REPO_REPO)
	@if ! grep -q -f $(HOST_SSH_KEY_PATH).pub authorized_keys ; then \
		cat $(HOST_SSH_KEY_PATH).pub >> authorized_keys; \
	else \
		echo >&2 "SSH key already authorized for util server. Skipping addition to authorized_keys."; \
	fi
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	sudo mkdir -p $(BACKUPS_HOST_BACKUP_DIR)
endif

$(HOST_SSH_KEY_PATH):
	mkdir -p $(HOST_SSH_DIR)
	ssh-keygen -t rsa -b 4096 -C "$(HOST_SSH_KEY_COMMENT)" -f $(HOST_SSH_KEY_PATH)

# The repository manager lives on the host in the repository root directory
$(HOST_REPO_REPO):
	$(SUDO) mkdir -p $(HOST_REPO_REPO)
	$(SUDO) git -C $(HOST_REPO_REPO) init --bare
	$(SUDO) cp git/pre-receive.py $(HOST_REPO_REPO)/hooks/pre-receive
	$(SUDO) chmod 755 $(HOST_REPO_REPO)/hooks/pre-receive

	# Create a commit in the repo, with the repositories repository as an 
	#   example of building within the repo.
	mkdir -p temp
	git -C temp init
	sed 's?root_dir:.*?root_dir: $(BACKUPS_HOST_GIT_DIR)?' git/repositories.template.yaml > temp/repositories.yaml
	git -C temp add .
	git -C temp commit -am "Created fresh repositories list."
	git -C temp remote add origin $(HOST_REPO_REPO)
	$(SUDO) git -C temp push origin master

	# For some reason, the remote refs can end up being owned by sudo, so
	#   use sudo for deleting
	$(SUDO) rm -rf temp

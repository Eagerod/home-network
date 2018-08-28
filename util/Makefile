include ../DockerMakefile

ifeq ($(shell uname),Linux)
HOST_REPOSITORY_LOCATION:=/var/lib/git
SUDO:=sudo
else
HOST_REPOSITORY_LOCATION:=/Users/${USER}/Desktop/git
SUDO:=
endif
HOST_REPO_REPO:=$(HOST_REPOSITORY_LOCATION)/repositories.git

DOCKER_IMAGE_NAME:=util
DOCKER_PORT_FORWARDS:=\
	-p 22:22\
	-v $(HOST_REPOSITORY_LOCATION):/var/lib/git
DOCKER_BUILD_ARGS:=\
	DEFAULT_BLOBSTORE_WRITE_ACL \
	DEFAULT_BLOBSTORE_READ_ACL \
	MULTI_REDDIT_SUBS_LOCATION \
	MULTI_REDDIT_SAVED_LOCATION

ifeq ($(shell uname),Linux)
DOCKER_PORT_FORWARDS+=\
	-v /var/lib/backups:/var/lib/backups \
	-v /var/lib/git:/var/lib/git
else
DOCKER_PORT_FORWARDS+= \
	-v D:/DockerBackups:var/lib/backups \
	-v D:/DockerGit:/var/lib/git
endif


image: repo-manager


# The repository manager lives on the host in the repository root directory
.PHONY: repo-manager
repo-manager: $(HOST_REPO_REPO)

$(HOST_REPO_REPO):
	$(SUDO) mkdir -p $(HOST_REPO_REPO)
	$(SUDO) git -C $(HOST_REPO_REPO) init --bare
	$(SUDO) cp git/pre-receive.py $(HOST_REPO_REPO)/hooks/pre-receive
	$(SUDO) chmod 755 $(HOST_REPO_REPO)/hooks/pre-receive

	# Create a commit in the repo, with the repositories repository as an 
	#   example of building within the repo.
	mkdir temp
	git -C temp init
	sed 's?root_dir:.*?root_dir: $(HOST_REPOSITORY_LOCATION)?' git/repositories.template.yaml > temp/repositories.yaml
	git -C temp add .
	git -C temp commit -am "Created fresh repositories list."
	git -C temp remote add origin $(HOST_REPO_REPO)
	$(SUDO) git -C temp push origin master

	# For some reason, the remote refs can end up being owned by sudo, so
	#   use sudo for deleting
	$(SUDO) rm -rf temp


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

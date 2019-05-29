# This Makefile is provided as an easy way to organize the requirements of
#   getting this repository fully up and running for a single instance.

#include common.make

SHELL=/bin/bash

PROJECT_ROOT_DIRECTORY:=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT_DIRECTORY:=$(shell if [ -d .git ]; then echo $(PROJECT_ROOT_DIRECTORY); else echo $(PROJECT_ROOT_DIRECTORY)home-network; fi)

DOCKER_COMPOSE_VERSION:=1.24.0

SSHD_CONFIG:=/etc/ssh/sshd_config
ROOT_HOME=$(shell echo ~root)
SSH_DIR:=$(ROOT_HOME)/.ssh
SSH_AUTHORIZED_KEYS:=$(SSH_DIR)/authorized_keys

FSTAB=/etc/fstab

FS_WATCH_LIMIT:=16384
FS_WATCH_FILE:=/proc/sys/fs/inotify/max_user_watches
SYSCTL_CONF:=/etc/sysctl.conf


BOOTSTRAP_TARGETS:=\
	install-dependencies \
	create-environment \
	configure-ssh-server \
	configure-network-shares \
	configure-local-symlinks \
	create-plex-volumes \
	set-watch-limits


.PHONY: $(BOOTSTRAP_TARGETS)

all: $(BOOTSTRAP_TARGETS)


# Bootstrap is currently only set up to work using apt-get, so if this isn't a
#   linux machine, we're going to have a bad time.
verify-platform:
	@if [ "$$(uname)" != "Linux" ]; then \
		echo >&2 "Bootstrap being run on a $$(uname) machine. Cannot continue."; \
		exit -1; \
	fi


# The full bootstrap requires installing packages and restarting/disabling
#   system services.
# Require root privileges to progress. 
verify-root:
	@if [ $${EUID} != 0 ]; then \
		echo >&2 "Bootstrap being run without sudo. Cannot continue."; \
		exit -1; \
	fi


install-dependencies: verify-platform verify-root
	@apt-get update -y
	@apt-get install -y \
		apcupsd \
		docker.io \
		git \
		nfs-common \
		openssh-server

	@curl -L "https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-$$(uname -s)-$$(uname -m)" -o /usr/bin/docker-compose
	@chmod 755 /usr/bin/docker-compose


# Check if this directory is the directory that the git repo lives in, and if
#   not, clone it to a directory here, and carry on in there.
create-environment:
	@if [ -d .git ] || [ -d home-network ]; then \
		exit; \
	else \
		git clone https://github.com/eagerod/home-network; \
	fi
	
	@$(MAKE) -C $(PROJECT_ROOT_DIRECTORY) env;


configure-ssh-server: verify-platform verify-root
	@sed -i -r 's/^[#\s]*(PasswordAuthentication).*$$/\1 no/' $(SSHD_CONFIG)
	@sed -i -r 's/^[#\s]*(PermitRootLogin).*$$/\1 prohibit-password/' $(SSHD_CONFIG)
	@sed -i -r 's/^[#\s]*(Port).*$$/\1 2222/' $(SSHD_CONFIG)

	@systemctl restart sshd

	@mkdir -p $(SSH_DIR)
	@touch $(SSH_AUTHORIZED_KEYS)
	@chmod -R 600 $(SSH_DIR)
	@chmod 700 $(SSH_DIR)
	@cat $(PROJECT_ROOT_DIRECTORY)/util-servers.pub | while read pubkey; do \
		if ! grep -q "$${pubkey}" $(SSH_AUTHORIZED_KEYS); then \
			echo "$${pubkey}" >> $(SSH_AUTHORIZED_KEYS); \
		fi; \
	done


# Make sure /etc/fstab supplies the correct mounts, and attempt to remount
#   everything that isn't yet mounted.
configure-network-shares: verify-platform verify-root
	@if [ -z "$${NFS_HOST}" ]; then \
		echo >&2 "Must include an NFS_HOST to set up mounts"; \
		exit 1; \
	fi
	
	@set -e && cat $(PROJECT_ROOT_DIRECTORY)/nfs_volumes.txt | while read share; do \
		remote=$$(echo $${share} | cut -d' ' -f1); \
		local=$$(echo $${share} | cut -d' ' -f2); \
		if grep -q $$(echo -e "$${NFS_HOST}:$${remote}") $(FSTAB) 2> /dev/null; then \
			continue; \
		fi; \
		mkdir -p $${local}; \
		echo "$${NFS_HOST}:$${remote} $${local} nfs rsize=8192,wsize=8192,timeo=14,intr 0 0" >> $(FSTAB); \
	done
	
	@mount -a
	

# If the destination path already exists, don't try to link again. If the 
#   destination path exists, and it's a directory, this would just add a 
#   symlink into the directory containing itself, which isn't very clean.
configure-local-symlinks: verify-platform verify-root
	@set -e && cat $(PROJECT_ROOT_DIRECTORY)/local_mounts.txt | while read localmount; do \
		mount=$$(echo $${localmount} | cut -d' ' -f1); \
		path=$$(echo $${localmount} | cut -d' ' -f2); \
		if [ ! -d $${path} ]; then \
			mkdir -p $${mount}; \
			mkdir -p $$(dirname $${path}); \
			ln -s $${mount} $${path}; \
		elif [ "$$(readlink $${path})" != "$${mount}" ]; then \
			echo "$${path} is poorly configured, and may already contain data."; \
			exit -1; \
		fi; \
	done


# The Plex server set up process requires that a `volumes.txt` exists so that
#   a `plex-volumes.yml` can be created.
create-plex-volumes: verify-platform verify-root
	@if [ ! -f $(PROJECT_ROOT_DIRECTORY)/plex/volumes.txt ]; then \
		echo "/dev/null /data/nothing" >> $(PROJECT_ROOT_DIRECTORY)/plex/volumes.txt; \
	fi

# Increase the number of file system watches that can be allocated.
# Tons of hosted applications set up watches, and the default limit is easy to
#   exceed.
set-watch-limits: verify-platform verify-root
	@echo $(FS_WATCH_LIMIT) > $(FS_WATCH_FILE)
	@sed -i "/^fs.inotify.max_user_watches.*/d" $(SYSCTL_CONF)
	@echo "fs.inotify.max_user_watches=$(FS_WATCH_LIMIT)" >> $(SYSCTL_CONF)

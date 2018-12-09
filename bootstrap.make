# This Makefile is provided as an easy way to organize the requirements of
#   getting this repository fully up and running for a single instance.

#include common.make

SHELL=/bin/bash

PROJECT_ROOT_DIRECTORY:=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
PROJECT_ROOT_DIRECTORY:=$(shell if [ -d .git ]; then echo $(PROJECT_ROOT_DIRECTORY); else echo $(PROJECT_ROOT_DIRECTORY)home-network; fi)

SSHD_CONFIG:=/etc/ssh/sshd_config
ROOT_HOME=$(shell echo ~root)
SSH_DIR:=$(ROOT_HOME)/.ssh
SSH_AUTHORIZED_KEYS:=$(SSH_DIR)/authorized_keys

BOOTSTRAP_TARGETS:=\
	verify-root \
	install-dependencies \
	create-environment \
	configure-ssh-server

PIHOLE_BOOTSTRAP_TARGETS:=$(BOOTSTRAP_TARGETS) disable-system-dns


.PHONY: $(PIHOLE_BOOTSTRAP_TARGETS)

all: $(BOOTSTRAP_TARGETS)

all-pihole: $(PIHOLE_BOOTSTRAP_TARGETS)


# The full bootstrap requires restarting and disabling system services.
# Require root privileges to progress. 
verify-root:
	@if [ $${EUID} != 0 ]; then \
		echo >&2 "Bootstrap being run without sudo. Cannot continue."; \
		exit -1; \
	fi


install-dependencies:
	@apt-get update -y
	@apt-get install -y \
		docker.io \
		docker-compose \
		git \
		openssh-server


# Check if this directory is the directory that the git repo lives in, and if
#   not, clone it to a directory here, and carry on in there.
create-environment:
	@if [ -d .git ] || [ -d home-network ]; then \
		exit; \
	else \
		git clone https://github.com/eagerod/home-network; \
	fi
	
	$(MAKE) -C $(PROJECT_ROOT_DIRECTORY) env-templates;


# Only disable system DNS if this machine will be hosting the pihole. If it's
#   not, keep system DNS enabled, or the machine will fail to resolve any DNS
#   lookups
disable-system-dns:
	systemctl disable systemd-resolved.service
	systemctl stop systemd-resolved


configure-ssh-server:
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

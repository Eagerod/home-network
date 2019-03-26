# This Makefile provides a few common elements that will be needed by any kind
#   of docker-oriented child makefile.
# This should be included in whatever Makefiles are written inside this project.
# It was introduced to keep as many definitions consistent as possible.

DOCKER_COMPOSE_PROJECT_NAME:=homenetwork
LOGS_DIRECTORY:=/var/log/$(DOCKER_COMPOSE_PROJECT_NAME)

# Try to go over different processes and attempt to avoid needing to ask the
#   user for their password.
ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
DOCKER_COMPOSE:=docker-compose
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
DOCKER:=eval $$(docker-machine env $(shell docker-machine ls -q)) && docker
DOCKER_COMPOSE:=eval $$(docker-machine env $(shell docker-machine ls -q)) && docker-compose
else ifeq ($(shell sudo docker ps > /dev/null && echo "pass"),pass)
DOCKER:=sudo docker
DOCKER_COMPOSE:=sudo -E docker-compose
else
$(error Cannot communicate with docker daemon)
endif

# Determine the platform of this machine. There will often be different paths,
#   or different tools that need to be chosen based on running on a different
#   platform.
UNAME:=$(shell uname)
PLATFORM_MACOS:=MacOS
PLATFORM_LINUX:=Linux
PLATFORM_WINDOWS:=Windows

ifeq ($(UNAME),Darwin)
PLATFORM:=$(PLATFORM_MACOS)
else ifeq ($(UNAME),Linux)
PLATFORM:=$(PLATFORM_LINUX)
else ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
PLATFORM:=$(PLATFORM_WINDOWS)
else
$(error Unknown distribution ($(UNAME)) for running these containers)
endif

# Copyable, consistent set of conditionals; must be in the defined order, and
#   if multiple platforms need similar behaviours, the first's position should
#   be taken for both.
#
# ifeq ($(PLATFORM),$(PLATFORM_MACOS))
# $(info Platform is MacOS)
# else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
# $(info Platform is Linus)
# else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
# $(info Platform is Windows)
# endif
#
# ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
# $(info Platform is MacOS, or Windows maybe)
# else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
# $(info Platform is Linus)
# endif
#

# Configure some platform specific commands, or prefixes so that any makefile
#   can use these without needing to check the platform.
ifeq ($(PLATFORM),$(PLATFORM_MACOS))
SED_INLINE:=sed -i ''
ATTACHED_DOCKER:=$(DOCKER)
DOCKER_COMPOSE_ENV:=HOST_DATA_DIR=~/Desktop/docker
COMPOSE_PLATFORM_FILE:=docker-compose.darwin.yml
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
SED_INLINE:=sed -i
ATTACHED_DOCKER:=$(DOCKER)
DOCKER_COMPOSE_ENV:=HOST_DATA_DIR=/var/lib
COMPOSE_PLATFORM_FILE:=docker-compose.linux.yml
CRON_BASE_PATH:=/etc/cron.d
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
SED_INLINE:=sed -i
ATTACHED_DOCKER:=winpty $(DOCKER)
DOCKER_COMPOSE_ENV:=HOST_DATA_DIR=D:
COMPOSE_PLATFORM_FILE:=docker-compose.cygwin.yml
endif

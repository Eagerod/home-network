# This Makefile provides a few common elements that will be needed by any kind
#   of docker-oriented child makefile.
# This should be included in whatever Makefiles are written inside this project.
# It was introduced to keep as many definitions consistent as possible.

# Try to go over different processes and attempt to avoid needing to ask the
#   user for their password.
ifeq ($(shell docker ps > /dev/null 2> /dev/null && echo "pass"),pass)
DOCKER:=docker
else ifeq ($(shell type docker-machine > /dev/null && echo "pass"),pass)
DOCKER:=eval $$(docker-machine env $(shell docker-machine ls -q)) && docker
else ifeq ($(shell sudo docker ps > /dev/null && echo "pass"),pass)
DOCKER:=sudo docker
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
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
SED_INLINE:=sed -i
ATTACHED_DOCKER:=$(DOCKER)
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
SED_INLINE:=sed -i
ATTACHED_DOCKER:=winpty $(DOCKER)
endif

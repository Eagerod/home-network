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

include ../docker.make

DOCKER_IMAGE_NAME:=sharelatex

# Note: Have to mount the entire sharelatex directory, even though `./data` is
#   really the only important directory. A temp directory can be created as well
#   but because of sharelatex implementing the temp directory with a `rename`
#   rather than a `mv`, the transaction can't cross file-system boundaries.
# See: https://stackoverflow.com/questions/43206198/
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
DOCKER_PORT_FORWARDS:=\
	-p 8081:80\
	-v /var/lib/sharelatex:/var/lib/sharelatex
else
DOCKER_PORT_FORWARDS:=\
	-p 8081:80\
	-v sharelatex-data:/var/lib/sharelatex
endif

.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	sudo mkdir -p /var/lib/sharelatex
else
	$(DOCKER) volume create --name sharelatex-data -d local
endif

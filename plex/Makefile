include ../docker.make


REQUIRED_ENV_VARS:=\
	ADVERTISE_IP


PLEX_PUBLIC_PORT:=32400

# http://blog.jgc.org/2016/07/lazy-gnu-make-variables.html
PLEX_PORT_FORWARD_OWNER=$(eval PLEX_PORT_FORWARD_OWNER:=$(shell upnpc -l | grep $(PLEX_PUBLIC_PORT) | awk '{print $3}' | cut -d '>' -f 2 | cut -d ':' -f 1 | tr -d $$'\n'))$(PLEX_PORT_FORWARD_OWNER)


# Set up port forwarding for Plex.
#
# This command will remove rules from the router once authentication works
#	 upnpc -d $$(upnpc -l | grep $(PLEX_PUBLIC_PORT) | awk '{print $$1}') tcp;
.PHONY: port-forwards
port-forwards: test-environment
	source .env && \
	if [ ! -z "$(PLEX_PORT_FORWARD_OWNER)" ] && [ "http://$(PLEX_PORT_FORWARD_OWNER):$(PLEX_PUBLIC_PORT)" != "$${ADVERTISE_IP}" ]; then \
		echo >&2 "There's already a device ($(PLEX_PORT_FORWARD_OWNER)) on the network that owns $(PLEX_PUBLIC_PORT)."; \
		exit -1; \
	fi

ifeq ($(PLATFORM),$(PLATFORM_MACOS))
	if [ -z "$(PLEX_PORT_FORWARD_OWNER)" ]; then \
		upnpc -e Plex -a $$(ipconfig getifaddr en0) $(PLEX_PUBLIC_PORT) $(PLEX_PUBLIC_PORT) TCP; \
	fi
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	if [ -z "$(PLEX_PORT_FORWARD_OWNER)" ]; then \
		upnpc -e Plex -a $$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($$i=="src") print $$(i+1)}') $(PLEX_PUBLIC_PORT) $(PLEX_PUBLIC_PORT) TCP; \
	fi
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
	$(error "Can't port forward on windows here yet.")
endif


plex-volumes.yml:
	printf "version: '3'\nservices:\n  plex:\n    volumes:\n" > $@
	awk '{print "      - "$$2":"$$1}' volumes.txt >> $@

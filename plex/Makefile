include ../docker.make


PLEX_PUBLIC_PORT:=32400


setup: plex-volumes.yml mount-volumes


plex-volumes.yml:
	printf "version: '3'\nservices:\n  plex:\n    volumes:\n" > plex-volumes.yml
	awk '{print "      - "$$2":"$$1}' volumes.txt >> plex-volumes.yml


.PHONY: mount-volumes
mount-volumes:
	mkdir -p /mnt/downloads /mnt/tv-shows
	sudo umount /mnt/downloads || true
	sudo umount /mnt/tv-shows || true
	sudo mount -t cifs //192.168.0.25/Downloads /mnt/downloads -o user=Aleem
	sudo mount -t cifs //192.168.0.25/TV\ Shows /mnt/tv-shows -o user=Aleem


# Set up port forwarding for Plex. If there's already a device on the network
#   that owns these 
#
# This command will remove rules from the router once authentication works
#	 upnpc -d $$(upnpc -l | grep $(PLEX_PUBLIC_PORT) | awk '{print $$1}') tcp;
.PHONY: port-forwards
port-forwards:
	# Note, this should be checking to make sure that the IP address of the
	#   local device isn't this one's, cause that shouldn't cause a failure.
	if upnpc -l | grep -q $(PLEX_PUBLIC_PORT); then \
		echo >&2 "There's already a device on the network that owns $(PLEX_PUBLIC_PORT)."; \
		exit -1; \
	fi

ifeq ($(PLATFORM),$(PLATFORM_MACOS))
	upnpc -e Plex -a $$(ipconfig getifaddr en0) $(PLEX_PUBLIC_PORT) $(PLEX_PUBLIC_PORT) TCP
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	upnpc -e Plex -a $$(ip route get 8.8.8.8 | awk '{for(i=1;i<=NF;i++) if ($$i=="src") print $$(i+1)}') $(PLEX_PUBLIC_PORT) $(PLEX_PUBLIC_PORT) TCP
else ifeq ($(PLATFORM),$(PLATFORM_WINDOWS))
	$(error "Can't port forward on windows here yet.")
endif

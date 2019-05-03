include ../docker.make

REQUIRED_ENV_VARS:=\
	ServerIP\
	ServerHostIP


PIHOLE_SEARCH_DOMAINS:=home local


lan.list: ../docker-compose.yml Makefile
	$(foreach domain,$(PIHOLE_SEARCH_DOMAINS),\
		source .env && python ../.scripts/get_hostnames.py ../docker-compose.yml | while read line; do \
			arr=($${line[@]}); \
			hostname=$${arr[0]}; \
			printf '$${SERVER_IP}	%s.%s.	%s\n' $$hostname $(domain) $$hostname >> $@; \
		done; \
	)

include ../docker.make


reverse-proxy.conf: reverse-proxy.template.conf ../docker-compose.yml
	@python ../.scripts/get_hostname_container_webserver_port.py ../docker-compose.yml | while read line; do \
		arr=($${line[@]}); \
		sed "s/"'$${HOSTNAME}'"/$${arr[0]}/g; s/"'$${HOSTPORT}'"/$${arr[1]}/g" reverse-proxy.template.conf >> $@; \
	done

include ../docker.make

DOCKER_IMAGE_NAME:=openvpn
DOCKER_PORT_FORWARDS:=\
	-p 943:943/tcp\
	-p 1194:1194/udp\
	-p 9443:9443/tcp\
	-v ~/Desktop/docker/openvpn-as:/config\
	-e INTERFACE=eth0\
	--privileged

# -e PGID=<gid> -e PUID=<uid> \

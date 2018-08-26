include ../DockerMakefile

DOCKER_IMAGE_NAME=pi-hole

# If the network manager is allowed to configure DNS, the pihole will try to
#   use itself as its own primary DNS server before it even boots up, so it'll
#   get stuck in a no-boot loop. If it only believes loopback to be its own
#   DNS, it actually skips the check, and there's no issue.
DOCKER_PORT_FORWARDS:=\
	-p 80:80\
	-p 53:53/tcp\
	-p 53:53/udp\
	-e ServerIP=${ServerIP}\
	--dns=127.0.0.1

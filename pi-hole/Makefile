include ../DockerMakefile

DOCKER_IMAGE_NAME=pi-hole
DOCKER_PORT_FORWARDS:=\
	-p 80:80\
	-p 53:53/tcp\
	-p 53:53/udp\
	-e ServerIP=${ServerIP}


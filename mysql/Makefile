include ../DockerMakefile

DOCKER_IMAGE_NAME:=mysql

ifeq ($(shell uname),Darwin)
DOCKER_PORT_FORWARDS:=\
	-p 3306:3306 \
	-v ~/Desktop/docker/mysql:/var/lib/mysql
else
DOCKER_PORT_FORWARDS:=\
	-p 3306:3306 \
	-v D:/DockerMySql/data:/var/lib/data
endif


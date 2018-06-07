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


# Initialization script to be run once on any given machine to set up the
#   /var/lib/data directory with the mysql database.
# Creates a mysql-ready container running bash, and submits the mysqld
#   initialize command to it with the approprite parameters.
.PHONY: initialize
initialize:
	$(MAKE) -C $(CURDIR) kill debug image detached
	$(DOCKER) exec -it $(RUNNING_CONTAINER_NAME) /usr/sbin/mysqld --datadir=/var/lib/data --pid-file=/var/lib/mysqld.pid --initialize

# Set the root password on my MySQL database to the value provided in the
#   `MYSQL_ROOT_PASSWORD` environment variable.
# Only works if the root password is at least 16 characters long.
.PHONY: password
password:
	@if [ $${#MYSQL_ROOT_PASSWORD} -lt 16 ]; then \
		echo >&2 "Root password too short, aborting password creation"; \
		exit -1; \
	fi
	$(MAKE) -C $(CURDIR) kill debug image detached
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) /usr/sbin/mysqld --datadir=/var/lib/data --pid-file=/var/lib/mysqld.pid --skip-grant-tables
	sleep 1
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) /usr/bin/mysql -u root -e "FLUSH PRIVILEGES; SET PASSWORD FOR root@'localhost' = PASSWORD('$${MYSQL_ROOT_PASSWORD}'); FLUSH PRIVILEGES;"
	$(MAKE) -C $(CURDIR) kill

# Create a bash session on a running mysql container to start a root mysql
#   session.
# Note: This doesn't start a mysql shell directly, because there seems to be
#   an issue with managing IO when starting the mysql in the docker exec
#   statement.
.PHONY: root-shell
root-shell:
	$(ATTACHED_DOCKER) exec -e MYSQL_PWD="$${MYSQL_ROOT_PASSWORD}" -it $(RUNNING_CONTAINER_NAME) /bin/bash

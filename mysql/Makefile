include ../DockerMakefile

DOCKER_IMAGE_NAME:=mysql

ifeq ($(shell uname),Darwin)
DOCKER_PORT_FORWARDS:=\
	-p 3306:3306 \
	-v ~/Desktop/docker/mysql:/var/lib/mysql
else ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
DOCKER_PORT_FORWARDS:=\
	-p 3306:3306 \
	-v mysql-data:/var/lib/data
else
$(error "Unsupported distro")
endif

MYSQL_DAEMON:=/usr/sbin/mysqld
MYSQL_CLIENT:=/usr/bin/mysql


.PHONY: verify-mysql-root-password
verify-mysql-root-password:
	@if [ -z "$${MYSQL_ROOT_PASSWORD}" ]; then \
		echo >&2 "Root password missing. A root password must be provided"; \
		exit -1; \
	fi

.PHONY: validate-mysql-root-password
validate-mysql-root-password: verify-mysql-root-password
	@if [ "$${#MYSQL_ROOT_PASSWORD}" -lt 16 ]; then \
		echo >&2 "Root password too short, aborting password creation"; \
		exit -1; \
	fi

.PHONY: verify-mysql-user
verify-mysql-user:
	@if [ -z "$${MYSQL_USER}" ]; then \
		echo >&2 "Must provide a username for this operation."; \
		exit -1; \
	fi

.PHONY: verify-mysql-password
verify-mysql-password: verify-mysql-user
	@if [ -z "$${MYSQL_PASSWORD}" ]; then \
		echo >&2 "Must provide a password for $${MYSQL_USER}"; \
		exit -1; \
	fi

.PHONY: verify-mysql-database
verify-mysql-database:
	@if [ -z "$${MYSQL_DATABASE}" ]; then \
		echo >&2 "Must provide a database for this operation."; \
		exit -1; \
	fi


# Initialization script to be run once on any given machine to set up the
#   /var/lib/data directory with the mysql database.
# On some machines (Windows, noteably), in order for permissions to be set up
#    correctly, a docker volume has to created, rather than just using normal
#    -v volume args
# Creates a mysql-ready container running bash, and submits the mysqld
#   initialize command to it with the approprite parameters.
.PHONY: initialize
initialize:
ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
	$(DOCKER) volume create --name mysql-data -d local
endif
	$(MAKE) -C $(CURDIR) kill debug image detached
ifeq ($(shell uname | grep -iq CYGWIN && echo "Cygwin"),Cygwin)
	$(ATTACHED_DOCKER) exec -it -u 0 $(RUNNING_CONTAINER_NAME) chown -R mysql:mysql /var/lib/data
endif
	$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) $(MYSQL_DAEMON) --datadir=/var/lib/data --pid-file=/var/lib/mysqld.pid --initialize

# Set the root password on my MySQL database to the value provided in the
#   `MYSQL_ROOT_PASSWORD` environment variable.
# Only works if the root password is at least 16 characters long.
.PHONY: password
password: validate-mysql-root-password
	$(MAKE) -C $(CURDIR) kill debug image detached
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) $(MYSQL_DAEMON) --datadir=/var/lib/data --pid-file=/var/lib/mysqld.pid --skip-grant-tables
	sleep 1
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(MYSQL_CLIENT) -u root -e "FLUSH PRIVILEGES; SET PASSWORD FOR root@'localhost' = PASSWORD('$${MYSQL_ROOT_PASSWORD}'); FLUSH PRIVILEGES;"
	$(MAKE) -C $(CURDIR) kill

# Create a bash session on a running mysql container to start a root mysql
#   session.
# Note: This doesn't start a mysql shell directly, because there seems to be
#   an issue with managing IO when starting the mysql in the docker exec
#   statement.
.PHONY: root-shell
root-shell: verify-mysql-root-password
	$(ATTACHED_DOCKER) exec -e MYSQL_PWD="$${MYSQL_ROOT_PASSWORD}" -it $(RUNNING_CONTAINER_NAME) /bin/bash

# Because docker (possibly only in windows with winpty?) seems to have issues
#   with starting up interactive subshells within an exec environment, this is
#   provided as a convenience tool to make sure that the appropriate SQL
#   queries can be submitted to the database to create users without needing
#   to start up interactive shell, which seems to have some issues on its own.
.PHONY: create-user
create-user: verify-mysql-root-password verify-mysql-user verify-mysql-password
	$(ATTACHED_DOCKER) exec -it -e MYSQL_PWD="$${MYSQL_ROOT_PASSWORD}" $(RUNNING_CONTAINER_NAME) $(MYSQL_CLIENT) -u root -e "\
		CREATE USER IF NOT EXISTS $${MYSQL_USER}@'%';\
		SET PASSWORD FOR $${MYSQL_USER}@'%' = PASSWORD('$${MYSQL_PASSWORD}');\
	"

# Grant a single user defined in an environment variable to have complete
#   access to a table defined in another environment variable.
.PHONY: grant-database
grant-database: verify-mysql-root-password verify-mysql-user verify-mysql-database
	$(ATTACHED_DOCKER) exec -it -e MYSQL_PWD="$${MYSQL_ROOT_PASSWORD}" $(RUNNING_CONTAINER_NAME) $(MYSQL_CLIENT) -u root -e "\
		CREATE DATABASE IF NOT EXISTS $${MYSQL_DATABASE}; \
		GRANT ALL ON $${MYSQL_DATABASE}.* TO $${MYSQL_USER}@'%';\
	"

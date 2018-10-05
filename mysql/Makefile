include ../docker.make

REQUIRED_ENV_VARS:=\
	MYSQL_ROOT_PASSWORD

MYSQL_CONTAINER_DATA_DIR:=/var/lib/data

ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
MYSQL_HOST_DATA_DIR:=mysql-data
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
MYSQL_HOST_DATA_DIR:=/var/lib/mysql
endif

MYSQL_DAEMON:=/usr/sbin/mysqld
MYSQL_CLIENT:=/usr/bin/mysql


setup: initialize env-password


env-password:
	source .env && $(MAKE) password


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
# On some machines (Windows, notably), in order for permissions to be set up
#    correctly, a docker volume has to created, rather than just using normal
#    -v volume args
# Creates a mysql-ready container running bash, and submits the mysqld
#   initialize command to it with the appropriate parameters.
.PHONY: initialize
initialize:
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
	$(SED_INLINE) 's/^RUN groupadd/# RUN groupadd/g' Dockerfile 
	$(SED_INLINE) 's/^RUN useradd/# RUN useradd/g' Dockerfile 
else ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	if ! grep -q mysql /etc/group; then \
		sudo groupadd mysql; \
	fi
	if ! id -u mysql; then \
	    sudo adduser --system --home /bin/false --no-create-home --disabled-password --disabled-login mysql; \
	fi

	$(SED_INLINE) "s/<gid>/$$(cat /etc/group | grep mysql | cut -d ':' -f3)/g" Dockerfile
	$(SED_INLINE) "s/<uid>/$$(cat /etc/passwd | grep mysql | cut -d ':' -f3)/g" Dockerfile

	sudo usermod -a -G mysql mysql
	sudo mkdir -p $(MYSQL_HOST_DATA_DIR)
	sudo chown mysql:mysql $(MYSQL_HOST_DATA_DIR)
endif

	$(SED_INLINE) 's/^CMD/# CMD/g' Dockerfile
	$(MAKE) -C .. debug/mysql
	sleep 1
ifeq ($(PLATFORM),$(filter $(PLATFORM),$(PLATFORM_MACOS) $(PLATFORM_WINDOWS)))
	$(ATTACHED_DOCKER) exec -it -u 0 $(RUNNING_CONTAINER_NAME) chown -R mysql:mysql $(MYSQL_CONTAINER_DATA_DIR)
endif
	if [ -z "$$($(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) ls $(MYSQL_CONTAINER_DATA_DIR))" ]; then \
		$(ATTACHED_DOCKER) exec -it $(RUNNING_CONTAINER_NAME) $(MYSQL_DAEMON) --datadir=$(MYSQL_CONTAINER_DATA_DIR) --pid-file=/var/lib/mysqld.pid --initialize; \
	fi
	$(SED_INLINE) 's/^# CMD/CMD/g' Dockerfile
	$(MAKE) kill

# Set the root password on my MySQL database to the value provided in the
#   `MYSQL_ROOT_PASSWORD` environment variable.
# Only works if the root password is at least 16 characters long.
.PHONY: password
password: validate-mysql-root-password
	$(SED_INLINE) 's?"/usr/sbin/mysqld", ?"/usr/sbin/mysqld", "--skip-grant-tables", ?g' Dockerfile
	$(MAKE) -C .. mysql
	sleep 1
	$(DOCKER) exec $(RUNNING_CONTAINER_NAME) $(MYSQL_CLIENT) -u root -e "FLUSH PRIVILEGES; SET PASSWORD FOR root@'localhost' = PASSWORD('$${MYSQL_ROOT_PASSWORD}'); FLUSH PRIVILEGES;"
	$(SED_INLINE) 's?"/usr/sbin/mysqld", "--skip-grant-tables", ?"/usr/sbin/mysqld", ?g' Dockerfile

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

.PHONY: validate_permissions
validate_permissions:
ifeq ($(PLATFORM),$(PLATFORM_LINUX))
	@if [ ! -z "$$(find $(MYSQL_HOST_DATA_DIR) ! -user mysql)" ]; then \
		echo >&2 "There are files in the mysql directory that aren't owned by the mysql user. This is bad".; \
		exit -1; \
	fi
endif

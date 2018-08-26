include ../docker.make

DOCKER_IMAGE_NAME:=firefly-iii
DOCKER_PORT_FORWARDS:=\
	-p 8082:80 \
	-e FF_DB_HOST=${FF_DB_HOST} \
	-e FF_DB_NAME=${FF_DB_NAME} \
	-e FF_DB_USER=${FF_DB_USER} \
	-e FF_DB_PASSWORD=${FF_DB_PASSWORD} \
	-e FF_APP_KEY=${FF_APP_KEY} \
	-e FF_APP_ENV=${FF_APP_ENV}

# Create the required database and user in the MySQL DB, and set up permissions
#   so that the snipeit user can do what they want.
#
# Run the database set up scripts that come bundled with firefly-iii too.
.PHONY: init-mysql
init-mysql:
	source ./.env && source $(CURDIR)/../mysql/.env && $(MAKE) -C $(CURDIR)/../mysql create-user
	source ./.env && source $(CURDIR)/../mysql/.env && $(MAKE) -C $(CURDIR)/../mysql grant-database

	$(MAKE) -C $(CURDIR) kill debug image detached
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan migrate
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:upgrade-database
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:verify
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan passport:install
	$(MAKE) -C $(CURDIR) kill


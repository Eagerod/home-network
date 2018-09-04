include ../docker.make

setup: initialize

# Create the required database and user in the MySQL DB, and set up permissions
#   so that the snipeit user can do what they want.
#
# Run the database set up scripts that come bundled with firefly-iii too.
.PHONY: initialize
initialize:
	$(MAKE) -C .. mysql
	source ./.env && source $(CURDIR)/../mysql/.env && $(MAKE) -C $(CURDIR)/../mysql create-user
	source ./.env && source $(CURDIR)/../mysql/.env && $(MAKE) -C $(CURDIR)/../mysql grant-database

	$(MAKE) -C .. $(DOCKER_IMAGE_NAME)
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan migrate
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:upgrade-database
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:verify
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan passport:install
	$(MAKE) -C $(CURDIR) kill


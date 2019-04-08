include ../docker.make

REQUIRED_ENV_VARS:=\
	MYSQL_USER\
	MYSQL_DATABASE\
	MYSQL_PASSWORD\
	FF_DB_PASSWORD\
	FF_APP_KEY\
	FF_APP_ENV

setup: initialize

# Create the required database and user in the MySQL DB, and set up permissions
#   so that the firefly user can do what they want.
#
# Run the database set up scripts that come bundled with firefly-iii too.
.PHONY: initialize
initialize:
	$(MAKE) -C .. mysql/setup
	$(MAKE) -C .. mysql
	
	# Give mysql a little time to finish booting and getting itself created in
	#   case this is the first time it being run.
	sleep 2

	source ./.env && $(MAKE) -C $(CURDIR)/../mysql create-user
	source ./.env && $(MAKE) -C $(CURDIR)/../mysql grant-database

	$(MAKE) -C .. $(DOCKER_IMAGE_NAME)
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan migrate
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:upgrade-database
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan firefly:verify
	$(DOCKER) exec -dit $(RUNNING_CONTAINER_NAME) php artisan passport:install
	$(MAKE) -C $(CURDIR) kill

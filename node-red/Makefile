include ../docker.make


REQUIRED_ENV_VARS:=\
	MYSQL_USER \
	MYSQL_DATABASE \
	MYSQL_PASSWORD \


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

#!/bin/bash
#
# Force the removal of several users, and modify some other configurations.
#
# The first time the container is started, there are a lot of configurations
#   that haven't been set up yet, so all of these commands will fail. Because
#   of that, `set -e` isn't included in here.

# # Delete users that likely exist in the user database
/usr/local/openvpn_as/scripts/sacli --user admin UserPropDelAll
/usr/local/openvpn_as/scripts/sacli --user openvpn UserPropDelAll

# Disable login for users that 
sed -i 's/^boot_pam_service=openvpnas/# boot_pam_service=openvpnas/' /config/etc/as.conf
sed -i -r 's/^(boot_pam_users.*)/# \1/' /config/etc/as.conf

# Remove users from the container that shouldn't be in there.
userdel admin
userdel openvpn

exec /init

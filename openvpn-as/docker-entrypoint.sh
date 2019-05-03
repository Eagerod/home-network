#!/bin/bash
#
# Force the removal of several users, and modify some other configurations.

CONFIG_FILE=/config/etc/as.conf

# # Delete users that likely exist in the user database
/usr/local/openvpn_as/scripts/sacli --user admin UserPropDelAll
/usr/local/openvpn_as/scripts/sacli --user openvpn UserPropDelAll

# Disable login for PAM users
sed -i -r 's/^(boot_pam_service.*)/# \1/g' $CONFIG_FILE
sed -i -r 's/^(boot_pam_users.*)/# \1/g' $CONFIG_FILE

echo "admin:$OPENVPN_PRIMARY_USERPASS" | chpasswd

exec /init

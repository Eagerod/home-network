#!/bin/bash
#
# Replace IP address with host IP, so the controller will tell the APs to 
#   inform to the right IP.
sed -i "s/"'${SERVER_IP}'"/${SERVER_HOST_IP}/g" /usr/lib/unifi/data/system.properties

exec /init

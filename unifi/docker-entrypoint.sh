#!/bin/bash
#
# Replace IP address with host IP, so the controller will tell the APs to 
#   inform to the right IP.
IS_DEFAULT=${IS_DEFAULT:-false}

echo "is_default=${IS_DEFAULT}" >> /usr/lib/unifi/data/system.properties

exec /init

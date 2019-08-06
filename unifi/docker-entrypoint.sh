#!/bin/bash
#
# Replace IP address with host IP, so the controller will tell the APs to 
#   inform to the right IP.
if [ -z "${UNIFI_SERVICE_IP}" ]; then
    echo >&2 "Need to provide UNIFI_SERVICE_IP"
    exit 1
fi

IS_DEFAULT=${IS_DEFAULT:-false}

sed -i "s/system_ip=.*/system_ip=${UNIFI_SERVICE_IP}/g" /usr/lib/unifi/data/system.properties
echo "is_default=${IS_DEFAULT}" >> /usr/lib/unifi/data/system.properties

exec /init

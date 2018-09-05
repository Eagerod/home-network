#!/bin/bash
#
# Set up the IP addresses of all lan-attached services to be the ip address of
#   the container that the pi-hole is running on.
# In a perfect world, this would ask the nginx service to give the IP address
#   of its host container, because it's possible that when running in a docker
#   swarm these will end up being different IP addresses, and resolution could
#   end up breaking.
sed -i "s/"'${SERVER_IP}'"/${ServerHostIP}/g" /etc/pihole/lan.list

exec ./s6-init

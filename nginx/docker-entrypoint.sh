#!/bin/bash
#
# Note -- This will probably always just end up being `127.0.0.11`, but
#   maintain this set up just so that if the container's resolver is ever
#   changed for any reason, this will catch it.
NAMESERVERS=$(cat /etc/resolv.conf | grep "nameserver" | awk '{print $2}' | tr '\n' ' ')

sed -i "s/"'${RESOLVERS}'"/${NAMESERVERS}/g" /etc/nginx/sites-available/reverse-proxy.conf

exec nginx -g "daemon off;"

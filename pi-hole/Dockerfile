FROM pihole/pihole

COPY ./setupVars.conf /etc/pihole/setupVars.conf

# LAN configuration
RUN echo "addn-hosts=/etc/pihole/lan.list" | tee /etc/dnsmasq.d/02-lan.conf
COPY ./lan.list /etc/pihole/lan.list

COPY docker-entrypoint.sh docker-entrypoint.sh
RUN chmod 755 docker-entrypoint.sh

# Overwrite the existing `/s6-init` entrypoint with one that updates the lan
#   list
ENTRYPOINT ["./docker-entrypoint.sh"]

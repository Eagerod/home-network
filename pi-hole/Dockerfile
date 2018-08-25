FROM pihole/pihole

COPY ./setupVars.conf /etc/pihole/setupVars.conf

# LAN configuration
RUN echo "addn-hosts=/etc/pihole/lan.list" | sudo tee /etc/dnsmasq.d/02-lan.conf
COPY ./lan.list /etc/pihole/lan.list

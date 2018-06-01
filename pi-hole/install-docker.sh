WHICH_SYSTEMCTL=$(which systemctl)
TMP_SYSTEMCTL=$(mktemp)

# Taken from https://github.com/diginc/docker-pi-hole/blob/master/install.sh
which systemctl && mv $WHICH_SYSTEMCTL $TMP_SYSTEMCTL
/bin/bash install.sh --unattended
mv $TMP_SYSTEMCTL $WHICH_SYSTEMCTL

grep -q '^user=root' || echo -e '\nuser=root' >> /etc/dnsmasq.conf


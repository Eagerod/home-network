WHICH_SYSTEMCTL=$(which systemctl)
TMP_SYSTEMCTL=$(mktemp)

which systemctl && mv $WHICH_SYSTEMCTL $TMP_SYSTEMCTL
/bin/bash -x install.sh --unattended
mv $TMP_SYSTEMCTL $WHICH_SYSTEMCTL


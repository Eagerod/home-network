#!/usr/bin/env sh

ACTUAL_DOMAIN=_acme-challenge.$CERTBOT_DOMAIN
SUBDOMAIN=$(echo -n $ACTUAL_DOMAIN | sed 's/.aleemhaji.com//')

wget -O - "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$NAMESILO_API_KEY&domain=aleemhaji.com" | \
	sed 's+<resource_record>+\'$'\n+g' | sed 's+</resource_record>+\'$'\n+g' | grep record_id | while read line; do
	NAMESILO_RECORD_ID=$(echo $line | sed -E 's/.*<record_id>([0-9a-f]{32}).*/\1/')
	if echo $line | grep '<type>A</type>' > /dev/null; then
		echo "Skipping A record because there's nothing to do with it"
	elif echo $line | grep '<type>CNAME</type>' > /dev/null; then
		echo "Skipping CNAME update because there's nothing to with it"
	elif echo $line | grep '<type>TXT</type>' > /dev/null; then
		if [ "$ACTUAL_DOMAIN" == "$(echo $line | sed -E 's/.*<host>([^<]*).*/\1/')" ]; then
			echo "Updating domain: $ACTUAL_DOMAIN with '$CERTBOT_VALIDATION'..."
			wget -O - "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=$NAMESILO_API_KEY&domain=aleemhaji.com&rrid=$NAMESILO_RECORD_ID&rrhost=$SUBDOMAIN&rrvalue=$CERTBOT_VALIDATION&rrttl=7207"
			echo "Sleeping for 30 minutes to wait for NameSilo DNS updates to propagate..."
			echo "Sleep is double their DNS update duration to ensure other DNS caches have time to expire."
			sleep 1800
			break
		else
			echo "Skipping TXT records because $ACTUAL_DOMAIN != $(echo $line | sed -E 's/.*<host>([^<]*).*/\1/')"
		fi
	else
		echo "Can't handle record ($line)"
	fi
done

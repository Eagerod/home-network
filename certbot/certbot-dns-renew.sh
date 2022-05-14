#!/usr/bin/env sh

ACTUAL_DOMAIN="_acme-challenge.$CERTBOT_DOMAIN"
SUBDOMAIN="$(printf "%s" "$ACTUAL_DOMAIN" | sed 's/.aleemhaji.com//')"

# Super primitive, but "works on my machine" XML field extractor.
# Probably basically only works for this script.
get_xml_fields() {
	if [ $# -lt 1 ] || [ $# -gt 2 ]; then
		echo >&2 "Usage: get_xml_field <key> [xml_string]"
		return 1
	fi

	the_key="$1"
	if [ $# -eq 2 ]; then
		the_xml="$2"
	else
		the_xml="$(cat -)"
	fi

	printf "%s" "$the_xml" |\
	sed -E "s+(</$the_key>)+\\1\\n+g" |\
	sed -E "s+.*(<$the_key>.*</$the_key>).*+\\1+g" |\
	grep "^<$the_key>" | grep "</$the_key>\$"
}

strip_xml() {
	if [ $# -lt 1 ] || [ $# -gt 2 ]; then
		echo >&2 "Usage: strip_xml <key> [xml_string]"
		return 1
	fi

	the_key="$1"
	if [ $# -eq 2 ]; then
		the_xml="$2"
	else
		the_xml="$(cat -)"
	fi

	printf "%s" "$the_xml" |\
	sed -E "s+.*<$the_key>(.*)</$the_key>.*+\\1+g"
}

wget -O - "https://www.namesilo.com/api/dnsListRecords?version=1&type=xml&key=$NAMESILO_API_KEY&domain=aleemhaji.com" | \
	get_xml_fields "resource_record" | while read -r line; do
	NAMESILO_RECORD_ID="$(get_xml_fields record_id "$line" | strip_xml record_id)"
	NAMESILO_RECORD_TYPE="$(get_xml_fields type "$line" | strip_xml type)"
	if [ "$NAMESILO_RECORD_TYPE" = "A" ]; then
		echo "Skipping A record because there's nothing to do with it"
	elif [ "$NAMESILO_RECORD_TYPE" = "CNAME" ]; then
		echo "Skipping CNAME update because there's nothing to with it"
	elif [ "$NAMESILO_RECORD_TYPE" = "TXT" ]; then
		NAMESILO_RECORD_DOMAIN="$(get_xml_fields host "$line" | strip_xml host)"
		if [ "$ACTUAL_DOMAIN" = "$NAMESILO_RECORD_DOMAIN" ]; then
			echo "Updating domain: $ACTUAL_DOMAIN with '$CERTBOT_VALIDATION'..."
			wget -O - "https://www.namesilo.com/api/dnsUpdateRecord?version=1&type=xml&key=$NAMESILO_API_KEY&domain=aleemhaji.com&rrid=$NAMESILO_RECORD_ID&rrhost=$SUBDOMAIN&rrvalue=$CERTBOT_VALIDATION&rrttl=7207"
			echo "Sleeping for 30 minutes to wait for NameSilo DNS updates to propagate..."
			echo "Sleep is double their DNS update duration to ensure other DNS caches have time to expire."
			sleep 1800
			break
		else
			echo "Skipping TXT records because $ACTUAL_DOMAIN != $NAMESILO_RECORD_DOMAIN"
		fi
	else
		echo "Can't handle record ($line)"
	fi
done

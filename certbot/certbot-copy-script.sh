#!/usr/bin/env sh
#
# Update secrets
set -euf

INTERNAL_WILDCARD_SECRET_NAME=internal-certificate-files
INTERNAL_WILDCARD_COMBINED_SECRET_NAME=internal-certificate-file
INTERNAL_WILDCARD_ARCHIVE=/etc/letsencrypt/archive/internal.aleemhaji.com-0001

WILDCARD_SECRET_NAME=external-certificate-files
WILDCARD_COMBINED_SECRET_NAME=external-certificate-file
WILDCARD_ARCHIVE=/etc/letsencrypt/archive/aleemhaji.com-0001

BARE_DOMAIN_SECRET_NAME=tls.aleemhaji.com
BARE_DOMAIN_COMBINED_SECRET_NAME=tls-pem.aleemhaji.com
BARE_DOMAIN_ARCHIVE=/etc/letsencrypt/archive/aleemhaji.com

replace_certificates() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo >&2 "Can't replace certs because cert name or path isn't present"
		exit 1
	fi

	cert_name="$1"
	cert_path="$2"

	rsa_keyfile="$(mktemp).rsa.key"

	latest_crt="$(find "$cert_path" -iname "fullchain*.pem" | sort -V | tail -1)"
	latest_key="$(find "$cert_path" -iname "privkey*.pem" | sort -V | tail -1)"

	openssl rsa -in "$latest_key" -out "$rsa_keyfile"

	echo "Updating ${KUBERNETES_NAMESPACE}/$cert_name..."
	kubectl create secret generic -n "${KUBERNETES_NAMESPACE}" "$cert_name" -o yaml \
			--dry-run=client \
			--save-config \
			--from-file="tls.key=$latest_key" \
			--from-file="tls.crt=$latest_crt" \
			--from-file="tls.rsa.key=$rsa_keyfile" |\
		kubectl apply -f -

	rm "$rsa_keyfile"
}

replace_combined_certificate() {
	if [ -z "$1" ] || [ -z "$2" ]; then
		echo >&2 "Can't replace certs because cert name or path isn't present"
		exit 1
	fi

	cert_name="$1"
	cert_path="$2"

	combined_file="$(mktemp).pem"

	latest_crt="$(find "$cert_path" -iname "fullchain*.pem" | sort -V | tail -1)"
	latest_key="$(find "$cert_path" -iname "privkey*.pem" | sort -V | tail -1)"

	cat "$latest_crt" "$latest_key" > "$combined_file"

	echo "Updating ${KUBERNETES_NAMESPACE}/$cert_name..."
	kubectl create secret generic -n "${KUBERNETES_NAMESPACE}" "$cert_name" -o yaml \
			--dry-run=client \
			--save-config \
			--from-file="keycert.pem=$combined_file" |\
		kubectl apply -f -

	rm "$combined_file"
}

replace_certificates "$INTERNAL_WILDCARD_SECRET_NAME" "$INTERNAL_WILDCARD_ARCHIVE"
replace_combined_certificate "$INTERNAL_WILDCARD_COMBINED_SECRET_NAME" "$INTERNAL_WILDCARD_ARCHIVE"

if ${INCLUDE_EXTERNAL_CERTS}; then
	replace_certificates "$WILDCARD_SECRET_NAME" "$WILDCARD_ARCHIVE"
	replace_combined_certificate "$WILDCARD_COMBINED_SECRET_NAME" "$WILDCARD_ARCHIVE"
fi

if ${INCLUDE_BARE_DOMAIN}; then
	replace_certificates "$BARE_DOMAIN_SECRET_NAME" "$BARE_DOMAIN_ARCHIVE"
	replace_combined_certificate "$BARE_DOMAIN_COMBINED_SECRET_NAME" "$BARE_DOMAIN_ARCHIVE"
fi

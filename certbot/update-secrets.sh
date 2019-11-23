#!/usr/bin/env sh
#
# Update secrets
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

INTERNAL_WILDCARD_SECRET_NAME=internal-certificate-files
INTERNAL_WILDCARD_COMBINED_SECRET_NAME=internal-certificate-file
INTERNAL_WILDCARD_ARCHIVE=/etc/letsencrypt/archive/internal.aleemhaji.com-0001

WILDCARD_SECRET_NAME=external-certificate-files
WILDCARD_COMBINED_SECRET_NAME=external-certificate-file
WILDCARD_ARCHIVE=/etc/letsencrypt/archive/aleemhaji.com-0001

replace_certificates() {
    if [ -z $1 ] || [ -z $2 ]; then
        echo >&2 "Can't replace certs because cert name or path aren't present"
        exit 1
    fi

    cert_name="$1"
    cert_path="$2"

    rsa_keyfile="$(mktemp).rsa.key"

    echo "Updating $cert_name..."
    openssl rsa -in $(find "$cert_path" -iname "privkey*.pem" | sort -n | tail -1) -out "$rsa_keyfile"
    /scripts/patch.py \
        "Bearer $TOKEN" \
        '
        {
            "data":{
                "tls.crt": "'$(base64 $(find "$cert_path" -iname "fullchain*.pem" | sort -n | tail -1) | tr -d '\n')'",
                "tls.key": "'$(base64 $(find "$cert_path" -iname "privkey*.pem" | sort -n | tail -1) | tr -d '\n')'",
                "tls.rsa.key": "'$(base64 "$rsa_keyfile" | tr -d '\n')'"
            }
        }' \
        "https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets/$cert_name" > /dev/null

    rm $rsa_keyfile
}

replace_combined_certificate() {
    if [ -z $1 ] || [ -z $2 ]; then
        echo >&2 "Can't replace certs because cert name or path aren't present"
        exit 1
    fi

    cert_name="$1"
    cert_path="$2"

    combined_file="$(mktemp).pem"

    echo "Updating $cert_name..."
    cat \
        $(find "$cert_path" -iname "fullchain*.pem" | sort -n | tail -1) \
        $(find "$cert_path" -iname "privkey*.pem" | sort -n | tail -1) > $combined_file
    /scripts/patch.py \
        "Bearer $TOKEN" \
        '
        {
            "data":{
                "keycert.pem": "'$(base64 "$combined_file" | tr -d '\n')'"
            }
        }' \
        "https://$KUBERNETES_SERVICE_HOST/api/v1/namespaces/default/secrets/$cert_name" > /dev/null

    rm $combined_file
}

replace_certificates "$INTERNAL_WILDCARD_SECRET_NAME" "$INTERNAL_WILDCARD_ARCHIVE"
replace_combined_certificate "$INTERNAL_WILDCARD_COMBINED_SECRET_NAME" "$INTERNAL_WILDCARD_ARCHIVE"
replace_certificates "$WILDCARD_SECRET_NAME" "$WILDCARD_ARCHIVE"
replace_combined_certificate "$WILDCARD_COMBINED_SECRET_NAME" "$WILDCARD_ARCHIVE"

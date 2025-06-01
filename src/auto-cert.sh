#!/bin/sh

OUT_DIR='auto-cert'
SERVER_CERT_DIR='/etc/nginx/certs'
ROOT_CA_NAME="${ROOTCA:=RootCa}"
LOCALHOST_CERT_NAME="${AUTOCERT:=shared}"
DOMAINS_EXT_FILE='domains.ext'
ROOT_CA_PATH="${SERVER_CERT_DIR}/${ROOT_CA_NAME}"
LOCALHOST_CERT_PATH="${OUT_DIR}/${LOCALHOST_CERT_NAME}"

_create_domains_ext() {
# Create new domains.ext file
cat <<EOF > $DOMAINS_EXT_FILE
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
EOF

# Get all domains from nginx config
LOCAL_DOMAINS=$(nginx -T 2>/dev/null | sed -nr "s/\sserver_name\s([^_ ]+);/\1/p" | uniq)

# Add localhost ans 127.0.0.1 to the list of domains
LOCAL_DOMAINS="$LOCAL_DOMAINS localhost 127.0.0.1"

# Iterate over LOCAL_DOMAINS and add lines to domains.ext
LOOP_COUNTER=1
for domain in localhost $LOCAL_DOMAINS; do
    echo "Adding domain: $domain"
    echo "DNS.$LOOP_COUNTER = $domain" >> domains.ext
    LOOP_COUNTER=$((LOOP_COUNTER+1))
done
}

_generate_root_cert() {
  openssl req -x509 -nodes -new -sha256 -days 1024 -newkey rsa:2048 -keyout ${ROOT_CA_PATH}.key -out ${ROOT_CA_PATH}.pem -subj "/C=CZ/CN=Local-Dev-Root-CA"
  openssl x509 -outform pem -in ${ROOT_CA_PATH}.pem -out ${ROOT_CA_PATH}.crt
}

_generate_shared_cert() {
  openssl req -new -nodes -newkey rsa:2048 -keyout ${LOCALHOST_CERT_PATH}.key -out ${LOCALHOST_CERT_PATH}.csr -subj "/C=CZ/ST=Stateless/L=GingerbreadCity/O=Localhost-Certificates/CN=localhost.local"
  openssl x509 -req -sha256 -days 1024 -in ${LOCALHOST_CERT_PATH}.csr -CA ${ROOT_CA_PATH}.pem -CAkey ${ROOT_CA_PATH}.key -CAcreateserial -extfile ${DOMAINS_EXT_FILE} -out ${LOCALHOST_CERT_PATH}.crt

  # Copy and overwrite certificates to nginx certs dir
  cp ${LOCALHOST_CERT_PATH}.crt ${SERVER_CERT_DIR}/
  cp ${LOCALHOST_CERT_PATH}.key ${SERVER_CERT_DIR}/
}

_init() {
  if [ ! -d "${OUT_DIR}" ]; then
      mkdir ${OUT_DIR}
  fi

  if [ ! -d "${SERVER_CERT_DIR}" ]; then
      mkdir ${SERVER_CERT_DIR}
  fi

  if [ ! -f "${ROOT_CA_PATH}.crt" ]; then
      echo "Generating root certificate..."
      _generate_root_cert
  fi
}

_init

echo "Regenerating shared certificate"
_create_domains_ext
_generate_shared_cert

rm $DOMAINS_EXT_FILE

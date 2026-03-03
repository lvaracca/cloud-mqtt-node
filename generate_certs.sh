#!/bin/bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Directory for certificates
CERT_DIR="certs"
mkdir -p "$CERT_DIR"

# Domain for the certificate
DOMAIN="${1:-mqtt.example.com}"

echo "Generating certificates for domain: $DOMAIN"

# 1. Generate CA Key and Certificate
if [[ ! -f "$CERT_DIR/ca.key" || ! -f "$CERT_DIR/ca.pem" ]]; then
    echo "Generating CA..."
    openssl genrsa -out "$CERT_DIR/ca.key" 2048
    openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -sha256 -days 3650 -out "$CERT_DIR/ca.pem" -subj "/CN=MQTT-CA"
else
    echo "CA exists, skipping..."
fi

# 2. Generate Server Key and Certificate
if [[ ! -f "$CERT_DIR/server.key" || ! -f "$CERT_DIR/server.crt" ]]; then
    echo "Generating Server Certificate..."
    openssl genrsa -out "$CERT_DIR/server.key" 2048
    openssl req -new -key "$CERT_DIR/server.key" -out "$CERT_DIR/server.csr" -subj "/CN=$DOMAIN"
    
    cat > "$CERT_DIR/server.ext" <<EXT
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
EXT

    openssl x509 -req -in "$CERT_DIR/server.csr" -CA "$CERT_DIR/ca.pem" -CAkey "$CERT_DIR/ca.key" -CAcreateserial -out "$CERT_DIR/server.crt" -days 365 -sha256 -extfile "$CERT_DIR/server.ext"
else
    echo "Server Certificate exists, skipping..."
fi

# 3. Read File Contents
CA_CERT=$(cat "$CERT_DIR/ca.pem")
TLS_CERT=$(cat "$CERT_DIR/server.crt")
TLS_KEY=$(cat "$CERT_DIR/server.key")

# 4. Write to terraform/terraform.tfvars
TFVARS_FILE="terraform/terraform.tfvars"
echo "Writing variables to $TFVARS_FILE..."

# Default variables if not set
PROJECT_ID="${GCP_PROJECT_ID:-my-project-id}"

cat > "$TFVARS_FILE" <<TFVARS
project_id = "${PROJECT_ID}"
domain_name = "${DOMAIN}"
ca_cert_pem = <<EOT
$CA_CERT
EOT
tls_cert = <<EOT
$TLS_CERT
EOT
tls_key = <<EOT
$TLS_KEY
EOT
TFVARS

echo "terraform.tfvars has been populated."

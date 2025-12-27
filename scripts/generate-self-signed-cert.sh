#!/bin/bash

# Script to generate self-signed certificate for local development
# Usage: ./generate-self-signed-cert.sh [domain]

DOMAIN=${1:-localhost}
CERT_DIR="./certs"
CERT_PATH="$CERT_DIR/$DOMAIN"

echo "Generating self-signed certificate for $DOMAIN..."

# Create cert directory
mkdir -p $CERT_PATH

# Generate private key
openssl genrsa -out $CERT_PATH/privkey.pem 2048

# Generate certificate signing request
openssl req -new -key $CERT_PATH/privkey.pem -out $CERT_PATH/cert.csr -subj "/CN=$DOMAIN"

# Generate self-signed certificate (valid for 365 days)
openssl x509 -req -days 365 -in $CERT_PATH/cert.csr -signkey $CERT_PATH/privkey.pem -out $CERT_PATH/fullchain.pem

# Create certificate chain (for nginx)
cat $CERT_PATH/fullchain.pem > $CERT_PATH/chain.pem

# Set permissions
chmod 600 $CERT_PATH/privkey.pem
chmod 644 $CERT_PATH/fullchain.pem

echo "Certificate generated in $CERT_PATH/"
echo ""
echo "To use this certificate:"
echo "1. Set SSL_ENABLED=true in .env"
echo "2. Set DOMAIN=$DOMAIN in .env"
echo "3. Update docker-compose.yml to mount certs volume"
echo "4. Restart nginx: docker compose restart nginx"


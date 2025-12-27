#!/bin/bash

# Script to obtain Let's Encrypt certificate
# Usage: ./get-certificate.sh your-domain.com your-email@example.com

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <domain> <email>"
  echo "Example: $0 example.com admin@example.com"
  exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "Obtaining Let's Encrypt certificate for $DOMAIN..."

# Update .env file with domain
if [ -f .env ]; then
  if grep -q "^DOMAIN=" .env; then
    sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|" .env
  else
    echo "DOMAIN=$DOMAIN" >> .env
  fi
  
  if grep -q "^SSL_ENABLED=" .env; then
    sed -i "s|^SSL_ENABLED=.*|SSL_ENABLED=true|" .env
  else
    echo "SSL_ENABLED=true" >> .env
  fi
else
  echo "DOMAIN=$DOMAIN" > .env
  echo "SSL_ENABLED=true" >> .env
fi

# Make sure nginx is running
echo "Starting nginx..."
docker compose up -d nginx

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
sleep 10

# Obtain certificate
echo "Requesting certificate from Let's Encrypt..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  --disable-hook-validation \
  -d $DOMAIN

if [ $? -eq 0 ]; then
  echo "Certificate obtained successfully!"
  echo "Reloading nginx..."
  docker compose exec nginx nginx -s reload
  echo ""
  echo "✓ Certificate obtained! Your site should now be accessible at https://$DOMAIN"
  echo "✓ Certbot will automatically renew the certificate every 12 hours"
else
  echo "✗ Failed to obtain certificate. Please check:"
  echo "  1. Domain DNS is pointing to this server"
  echo "  2. Port 80 is open in firewall"
  echo "  3. Nginx is running and accessible"
  exit 1
fi


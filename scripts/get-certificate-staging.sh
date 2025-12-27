#!/bin/bash

# Script to obtain Let's Encrypt STAGING certificate (for testing)
# Usage: ./get-certificate-staging.sh your-domain.com your-email@example.com
# 
# NOTE: For Let's Encrypt to work, your domain MUST:
# 1. Point to this server's public IP address
# 2. Have port 80 open and accessible from internet
# 3. Be publicly resolvable (not localhost)

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <domain> <email>"
  echo "Example: $0 example.com admin@example.com"
  echo ""
  echo "IMPORTANT: Domain must point to this server's public IP!"
  exit 1
fi

DOMAIN=$1
EMAIL=$2

echo "Obtaining Let's Encrypt STAGING certificate for $DOMAIN..."
echo "WARNING: This uses Let's Encrypt staging environment (for testing)"
echo ""

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

# Obtain STAGING certificate (doesn't count against rate limits)
echo "Requesting STAGING certificate from Let's Encrypt..."
docker compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --staging \
  --email $EMAIL \
  --agree-tos \
  --no-eff-email \
  --force-renewal \
  --disable-hook-validation \
  -d $DOMAIN

if [ $? -eq 0 ]; then
  echo "STAGING certificate obtained successfully!"
  echo "Reloading nginx..."
  docker compose exec nginx nginx -s reload
  echo ""
  echo "Certificate obtained! Your site should now be accessible at https://$DOMAIN"
  echo ""
  echo "NOTE: This is a STAGING certificate - browsers will show a warning!"
  echo "For production, use get-certificate.sh (without --staging flag)"
else
  echo "Failed to obtain certificate. Please check:"
  echo "  1. Domain DNS is pointing to this server's public IP"
  echo "  2. Port 80 is open in firewall and accessible from internet"
  echo "  3. Nginx is running and accessible"
  exit 1
fi


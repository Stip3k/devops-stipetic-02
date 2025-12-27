#!/bin/sh
set -e

DOMAIN=${DOMAIN:-localhost}
SSL_ENABLED=${SSL_ENABLED:-false}

# Process HTTP config
sed "s|localhost|${DOMAIN}|g" /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf

# Process SSL config only if SSL is enabled and certificates exist
if [ "$SSL_ENABLED" = "true" ]; then
    # Check for Let's Encrypt certificate first
    if [ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]; then
        echo "SSL enabled - using Let's Encrypt certificate..."
        CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"
    # Check for self-signed certificate
    elif [ -f "/etc/nginx/certs/${DOMAIN}/fullchain.pem" ]; then
        echo "SSL enabled - using self-signed certificate..."
        CERT_PATH="/etc/nginx/certs/${DOMAIN}"
    else
        echo "SSL enabled but no certificate found. Skipping SSL configuration."
        SSL_ENABLED="false"
    fi
    
    if [ "$SSL_ENABLED" = "true" ]; then
        # Create SSL config with correct certificate paths
        sed "s|\${DOMAIN}|${DOMAIN}|g" /etc/nginx/conf.d/default-ssl.conf.template | \
        sed "s|/etc/letsencrypt/live/\${DOMAIN}|${CERT_PATH}|g" | \
        sed "s|/etc/letsencrypt/live/${DOMAIN}|${CERT_PATH}|g" > /etc/nginx/conf.d/default-ssl.conf
        
        # Update HTTP config to redirect to HTTPS
        cat > /etc/nginx/conf.d/default.conf <<EOF
# HTTP server - redirects to HTTPS and handles Let's Encrypt challenges
server {
    listen 80;
    server_name ${DOMAIN};

    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF
    fi
else
    echo "SSL disabled - using HTTP only for local development"
    # Remove SSL config if it exists
    rm -f /etc/nginx/conf.d/default-ssl.conf
fi

# Test nginx configuration
nginx -t

# Start nginx
exec nginx -g 'daemon off;'

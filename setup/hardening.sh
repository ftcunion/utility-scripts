#!/bin/sh

# ensure the script exits on error
set -e

# variables
DOMAIN="ftcunion.org"

# First, block all direct access to the web server.
echo "Blocking ALL access to the web server for domain: $DOMAIN"
httpauth "$DOMAIN" -path=/

# Clear any existing whitelists to ensure we start fresh.
echo "Clearing existing whitelists for domain: $DOMAIN"
httpauth "$DOMAIN" -whitelist -delete-all
#        ^ This domain part is currently useless

# Now, get the Cloudflare IPs and allow access to them.
echo "Allowing access to Cloudflare IPs for domain: $DOMAIN"
curl -s https://www.cloudflare.com/ips-v4 | while read -r ip; do
    httpauth "$DOMAIN" -whitelist="$ip"
    #        ^ This domain part is currently useless
done

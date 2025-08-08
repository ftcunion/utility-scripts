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

# Enable Cloudflare Authenticated Origin Pulls if files do not exist.
if [ ! -f "/var/www/$DOMAIN/cloudflare-mtls-nginx.conf" ] || [ ! -f "/etc/nginx/certs/cloudflare-mtls.pem" ]; then
	echo "Copying Cloudflare Authenticated Origin Pulls config and certificate for $DOMAIN"
	# Nginx config gets read if it ends with -nginx.conf
	cat <<-EOF >/var/www/$DOMAIN/cloudflare-mtls-nginx.conf
		ssl_verify_client on;
		ssl_client_certificate /etc/nginx/certs/cloudflare-mtls.pem;
	EOF
	# Copy the *public* certificate that will be used to verify Cloudflare's mTLS connections
	mkdir -p /etc/nginx/certs
	cat <<-EOF >/etc/nginx/certs/cloudflare-mtls.pem
		-----BEGIN CERTIFICATE-----
		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
		0w==
		-----END CERTIFICATE-----
	EOF

	chmod 600 /var/www/$DOMAIN/cloudflare-mtls-nginx.conf
	chmod 400 /etc/nginx/certs/cloudflare-mtls.pem

	if nginx -t; then
		echo "Nginx configuration test passed. Reloading Nginx..."
		systemctl reload nginx
	else
		echo "Nginx configuration test failed. Please check /var/www/$DOMAIN/cloudflare-mtls-nginx.conf."
		exit 1
	fi
else
	echo "Cloudflare mTLS already configured for $DOMAIN. Skipping..."
fi

# Setting up UWF (Uncomplicated Firewall)
if ! command -v ufw >/dev/null; then
	echo "UFW is not installed. Installing UFW..."
	apt-get update
	apt-get install -y ufw
fi

# UFW limit ssh and allow https
if ufw status | grep -qw "Status: inactive"; then
	echo "Configuring UFW to allow HTTPS and limit SSH access."
	ufw allow https
	ufw limit ssh
	echo "You should run 'ufw enable' to apply these changes."
elif ufw status | grep -qw "Status: active"; then
	echo "UFW is already active. Skipping..."
else
	echo "UFW error. Expected either 'Status: inactive' or 'Status: active', but got:"
	ufw status
	exit 1
fi

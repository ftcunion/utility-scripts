#!/bin/bash
# Arguments:
# $1 - domain name (e.g. chat.ftcunion.org)
# $2 - port number to proxy to (e.g. 8080)

# ensure the script exits on error
set -e

# Verify that both arguments are provided and that the port is a number
if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <domain> <port>"
	exit 1
fi
if [[ -f "/etc/nginx/apps.d/$1-proxy.conf" ]]; then
	echo "Error: The proxy configuration file already exists."
	exit 1
fi
if ! [[ "$2" =~ ^[0-9]+$ ]]; then
	echo "Error: Port must be a number."
	exit 1
fi

# add a new proxy site in webinoly
site "$1" -proxy=["127.0.0.1:$2"]

# enable SSL for the new site using existing certificates if domain ends with ftcunion.org and the cert files exist
if [[ "$1" == *.ftcunion.org ]] && [ -f /etc/nginx/certs/ftcunion.org.pem ] && [ -f /etc/nginx/certs/ftcunion.org.key ]; then
	echo "Enabling SSL for $1 using existing ftcunion.org certificates."
	site "$1" -ssl=on -ssl-key=/etc/nginx/certs/ftcunion.org.key -ssl-crt=/etc/nginx/certs/ftcunion.org.pem
else
	echo "SSL certificates for $1 not found. Falling back to snakeoil SSL."
	site "$1" -ssl=on -ssl-key=/etc/ssl/private/ssl-cert-snakeoil.key -ssl-crt=/etc/ssl/certs/ssl-cert-snakeoil.pem
fi

# check that the proxy config file was created
if [ -f "/etc/nginx/apps.d/$1-proxy.conf" ]; then
	echo "Proxy configuration file created successfully."

	# if the mtls cert is present, enable cloudflare authenticated origin pulls
	if [ -f "/etc/nginx/certs/cloudflare-mtls.pem" ]; then
		cat <<-EOF >>"/etc/nginx/apps.d/$1-proxy.conf"
			ssl_verify_client on;
			ssl_client_certificate /etc/nginx/certs/cloudflare-mtls.pem;
		EOF
	fi

	# uncomment the line to pass the original host header
	sed -i -E \
		's|^(\s*)#(proxy_set_header Host \$host;$)|\1\2|' \
		"/etc/nginx/apps.d/$1-proxy.conf"
	# add cloudflare real ip header
	sed -i -E \
		's|^(\s*)(#proxy_set_header X-Real-IP \$remote_addr;$)|\1\2\n\1real_ip_header CF-Connecting-IP;|' \
		"/etc/nginx/apps.d/$1-proxy.conf"

	# test nginx config and reload if successful
	if nginx -t; then
		echo "Nginx configuration test successful. Reloading nginx..."
		systemctl reload nginx
		echo "Nginx reloaded successfully."
	else
		echo "Error: Nginx configuration test failed. Please check the configuration."
		exit 1
	fi
else
	echo "Error: Failed to create the proxy configuration file."
	exit 1
fi

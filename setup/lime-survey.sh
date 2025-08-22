#!/bin/sh

# ensure the script exits on error
set -e

# variables
DOMAIN="survey.ftcunion.org"
CERTPATH="/etc/nginx/certs/ftcunion.org"
GIT_DIR="$(git rev-parse --show-toplevel)"

# only run commands to install the web server if the .installed file does not exist
if [ ! -f /root/.lsinstalled ]; then
	site "$DOMAIN" -php -mysql='[localhost,limesurvey,limesurvey,random]'

	# use real certs if we have them, otherwise use snakeoil
	if [ -f "$CERTPATH.key" ] && [ -f "$CERTPATH.pem" ]; then
		echo "Using secure ssl certificates for $DOMAIN"
		site "$DOMAIN" -ssl=on -ssl-key="$CERTPATH.key" -ssl-crt="$CERTPATH.pem"
	else
		echo "Using self-signed ssl certificates for $DOMAIN"
		site "$DOMAIN" -ssl=on -ssl-key=/etc/ssl/private/ssl-cert-snakeoil.key -ssl-crt=/etc/ssl/certs/ssl-cert-snakeoil.pem
	fi

	echo "Copy the database password and rerun this script to install or update LimeSurvey."

	# create the .lsinstalled file to indicate installation is complete
	touch /root/.lsinstalled
else
	echo "Let's get the latest version of LimeSurvey for $DOMAIN"
	cd "/var/www/$DOMAIN"

	# scrape the latest LimeSurvey download URL from the website
	DERIVED_UPDATE_URL="$(curl -s https://community.limesurvey.org/downloads/ | sed -n 's/.*\(https:\/\/download\.limesurvey\.org\/latest-master\/.*\.zip\).*/\1/p')"

	# ask the user if they want to use the derived URL or provide their own
	echo "The derived download URL for LimeSurvey is: $DERIVED_UPDATE_URL"
	echo "Enter a custom download URL or press Enter to use the derived URL: "
	read -r CUSTOM_URL

	# temporary file and directory for downloading and extracting LimeSurvey
	TEMP_FILE="$(sudo -u www-data mktemp --suffix .zip)"
	TEMP_DIR="$(sudo -u www-data mktemp -d)"
	trap 'rm -f "$TEMP_FILE"' EXIT
	trap 'rm -rf "$TEMP_DIR"' EXIT

	# download the LimeSurvey zip file as the www-data user
	sudo -u www-data wget -O "$TEMP_FILE" "${CUSTOM_URL:-$DERIVED_UPDATE_URL}"

	# extract the downloaded zip file into the temporary directory
	sudo -u www-data unzip -o "$TEMP_FILE" -d "$TEMP_DIR"

	# determine whether this is an initial install or an update
	if [ -f "./htdocs/index.php" ]; then
		echo "Updating LimeSurvey..."

		# perform backup
		"$GIT_DIR/backup.sh"

		# Sync new version files to the destination.
		# Excludes:
		#   - application/config/security.php
		#   - application/config/config.php
		#   - the upload directory
		echo "Syncing new files to $DEST_DIR..."
		# there should only be one directory in the temp dir, but it apparently changes sometimes
		for src in "$TEMP_DIR"/*/; do
			sudo -u www-data rsync -av --exclude='application/config/security.php' \
				--exclude='application/config/config.php' \
				--exclude='upload' \
				"$src/" "./htdocs/"
		done

		# Update the database schema using LimeSurvey's console command.
		echo "Updating the database..."
		sudo -u www-data php "./htdocs/application/commands/console.php" updatedb
	else
		echo "Installing LimeSurvey..."
		# perform installation steps
		# there should only be one directory in the temp dir, but it apparently changes sometimes
		for src in "$TEMP_DIR"/*/; do
			sudo -u www-data rsync -a "$src/" "./htdocs/"
			break
		done
	fi

	# clean up temporary files
	rm -f "$TEMP_FILE"
	rm -rf "$TEMP_DIR"
fi

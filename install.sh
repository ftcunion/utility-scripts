#!/bin/sh

# ensure the script exits on error
set -e

# variables
DOMAIN="ftcunion.org"
USER="mwt"

# install commands that I expect to use
apt-get update
apt-get install -y sudo git rsync ssl-cert curl byobu micro

# create user mwt, set random password, add to sudo group, and add first line of root's .ssh/authorized_keys
echo "Creating user $USER..." && {
    useradd -m -s /bin/bash "$USER"
    echo "$USER:$(openssl rand -base64 12)" | chpasswd
    usermod -aG 'sudo' "$USER"
    mkdir -p "/home/$USER/.ssh"
    head -n 1 "/root/.ssh/authorized_keys" >"/home/$USER/.ssh/authorized_keys"
    chmod 700 "/home/$USER/.ssh"
    chmod 600 "/home/$USER/.ssh/authorized_keys"
    chown -R "$USER:$USER" "/home/$USER/.ssh"
}

# webinoly clean installation
wget -qO weby qrok.es/wy && bash weby -clean

# patch webinoly config to allow remaining storage commands
sed -i -E 's;^#(php-disable-functions:.*,)(diskfreespace,disk_free_space,)(.*)$;#\1\2\3\n\1\3;' '/opt/webinoly/webinoly.conf'

# now build the stacksite "$DOMAIN" -wp
# here we're using the 'light' option to not install additional tools (only core packages)
# let's encrypt, backups, postfix, redis, memcached, phpmyadmin, etc, will not be installed.
# also, you can use the 'basic' option, or install individual tools according to your needs.
stack -lemp -build=light
# install redis
stack -redis
# install backups
stack -backups

# set up basic wordpress site
site "$DOMAIN" -wp -force-redirect=www

# enable ssl with self-signed certificate
site "$DOMAIN" -ssl=on -ssl-key=/etc/ssl/private/ssl-cert-snakeoil.key -ssl-crt=/etc/ssl/certs/ssl-cert-snakeoil.pem

# disable http authentication for wp-admin
httpauth "$DOMAIN" -wp-admin=off

# install custom theme
cd "/var/www/$DOMAIN/htdocs" && {
    # install stewart base theme
    if [ ! -d ./wp-content/themes/stewart ]; then
        # download stewart theme
        wget --timeout=15 -t 1 -qrO ./stewart-theme.zip 'https://downloads.wordpress.org/theme/stewart.latest-stable.zip'
        if [ -s ./stewart-theme.zip ]; then
            unzip -qq ./stewart-theme.zip -d ./wp-content/themes/
            rm ./stewart-theme.zip
            echo ""
            echo "Stewart Theme has been installed!"
        else
            echo "[ERROR] Downloading Stewart theme failed!"
        fi
    else
        echo "Stewart Theme is already installed!"
    fi
    # install stewart child theme
    if [ ! -d ./wp-content/themes/ftcunion-stewart ]; then
        git clone 'https://github.com/ftcunion/ftcunion-stewart.git' ./wp-content/themes/ftcunion-stewart
        if [ -d ./wp-content/themes/ftcunion-stewart ]; then
            echo ""
            echo "Stewart Child Theme has been installed!"
        else
            echo "[ERROR] Downloading Stewart Child theme failed!"
        fi
    else
        echo "Stewart Child Theme is already installed!"
    fi
}

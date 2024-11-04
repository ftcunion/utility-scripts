#!/bin/sh

# ensure the script exits on error
set -e

cd /root/backups

# backup the webinoly configuration
webinoly -backup=local -export -destination=.

# use find to delete all backups older than 3 days
find . -maxdepth 1 -type f -mtime +2 -exec rm {} \;

# apply xz to compress all uncompressed backups
find . -maxdepth 1 -type f ! -name '*.xz' -exec xz -z {} \;

# upload to google drive
rclone sync --transfers=8 --checkers=16 --drive-chunk-size=256M --retries=3 --low-level-retries=10 ./ gdrive:/website/backups/

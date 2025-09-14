#!/bin/sh

# ensure the script exits on error
set -e

ZULIP_BACKUPS=/root/backups/zulip
current_month="$(date '+%Y-%m')"
current_dtime="$(date +%F)-$(date +%T)"

# Ensure tmp directory is writeable by zulip container
chmod 777 "$ZULIP_BACKUPS/tmp"
rm -f "$ZULIP_BACKUPS/tmp/backup.tar.gz"

# Create the tarball (this folder is mapped to $ZULIP_BACKUPS/tmp)
docker compose -f /opt/stacks/zulip/compose.yaml exec -u zulip zulip \
	/home/zulip/deployments/current/manage.py backup --skip-uploads --automated --output /backups/backup.tar.gz

# if zbackup folder does not exist, create it
if [ ! -d "$ZULIP_BACKUPS/zbackup" ]; then
	mkdir -p "$ZULIP_BACKUPS/zbackup"
fi

cd "$ZULIP_BACKUPS/zbackup"

# we want one complete backup each month and incremental backups for each day
if [ ! -d "$current_month" ]; then
	# create current month directory
	mkdir "$current_month"
	# init zbackup for current month
	zbackup init --non-encrypted "$current_month"
fi

# run the zulip backup through zbackup
gzip -dc "$ZULIP_BACKUPS/tmp/backup.tar.gz" | zbackup backup --non-encrypted "./$current_month/backups/zulip_full_$current_dtime"

# delete temporary file
rm -f "$ZULIP_BACKUPS/tmp/backup.tar.gz"

# upload to b2 unless -n option is set
while getopts 'n' opt; do
	case "${opt}" in
	n)
		echo "Skipping cleanup and upload to Backblaze B2"
		exit 0
		;;
	*) echo "Invalid option: ${opt}" ;;
	esac
done

# upload to b2
rclone copy --transfers 24 --checkers=48 --b2-chunk-size=60M --retries=3 --low-level-retries=10 ./ b2-east:zulip-backups/

# delete old months when older than 50 days (they should be on b2)
find . -maxdepth 1 -mindepth 1 -type d -mtime +50 ! -name "$current_month" ! -name '.*' -exec rm -r {} \;

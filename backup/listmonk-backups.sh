#!/bin/sh

# ensure the script exits on error
set -e

BACKUPS_DIR=/root/backups/listmonk
current_month="$(date '+%Y-%m')"
current_dtime="$(date +%F)-$(date +%T)"

# if zbackup folder does not exist, create it
if [ ! -d "$BACKUPS_DIR/zbackup" ]; then
	mkdir -p "$BACKUPS_DIR/zbackup"
fi

cd "$BACKUPS_DIR/zbackup"

# we want one complete backup each month and incremental backups for each day
if [ ! -d "$current_month" ]; then
	# create current month directory
	mkdir "$current_month"
	# init zbackup for current month
	zbackup init --non-encrypted "$current_month"
fi

# run the pg_dump backup through zbackup
docker compose -f /opt/stacks/listmonk/compose.yaml exec -u postgres db pg_dump -U listmonk listmonk |
	zbackup backup --non-encrypted "./$current_month/backups/listmonk_db_$current_dtime"

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
rclone copy --transfers 24 --checkers=48 --b2-chunk-size=60M --retries=3 --low-level-retries=10 ./ b2-east:listmonk-backups/

# delete old months when older than 50 days (they should be on b2)
find . -maxdepth 1 -mindepth 1 -type d -mtime +50 ! -name "$current_month" ! -name '.*' -exec rm -r {} \;

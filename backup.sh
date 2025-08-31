#!/bin/sh

# ensure the script exits on error
set -e

current_month="$(date '+%Y-%m')"
current_dtime="$(date +%F)-$(date +%T)"

# if zbackup folder does not exist, create it
if [ ! -d /root/zbackup ]; then
    mkdir -p /root/zbackup
fi

cd /root/zbackup

# we want one complete backup each month and incremental backups for each day
if [ ! -d "$current_month" ]; then
    # create current month directory
    mkdir "$current_month"
    # init zbackup for current month
    zbackup init "$current_month" --non-encrypted
fi

# backup the webinoly configuration
TEMP_FILE="$(mktemp /tmp/webinoly_full_backup.XXXXXX)"
trap 'rm -f "$TEMP_FILE"' EXIT
webinoly -backup=local -export -destination=/tmp -filename="$(basename "$TEMP_FILE")"

# run the webinoly backup through zbackup
cat "$TEMP_FILE" | zbackup backup --non-encrypted "./$current_month/backups/webinoly_$current_dtime"

# delete temporary file
rm -f "$TEMP_FILE"

# compress all uncompressed backups and upload to b2 unless -n option is set
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
rclone copy --transfers 24 --checkers=48 --b2-chunk-size=60M --retries=3 --low-level-retries=10 ./ b2:webinoly-backups/

# delete old months (they should be on b2)
find . -maxdepth 1 -mindepth 1 -type d ! -name "$current_month" ! -name '.*' -exec rm -r {} \;

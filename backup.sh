#!/bin/sh

# ensure the script exits on error
set -e

cd /root/backups

# backup the webinoly configuration
webinoly -backup=local -export -destination=.

# if there are more than three files, use find to delete all backups older than 3 days
if [ "$(find . -maxdepth 1 -type f -printf '1' | wc -c)" -gt 3 ]; then
    find . -maxdepth 1 -type f -mtime +2 -exec rm {} \;
fi

# compress all uncompressed backups and upload to b2 unless -n option is set
while getopts 'n' opt; do
    case "${opt}" in
    n)
        echo "Skipping upload to Backblaze B2"
        exit 0
        ;;
    *) echo "Invalid option: ${opt}" ;;
    esac
done

# apply xz to compress all uncompressed backups
find . -maxdepth 1 -type f ! -name '*.xz' -exec xz -z {} \;
# upload to b2
rclone copy --transfers 24 --checkers=48 --b2-chunk-size=60M --retries=3 --low-level-retries=10 ./ b2:webinoly-backups/

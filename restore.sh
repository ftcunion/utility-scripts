#!/bin/sh

# ensure the script exits on error
set -e

# get the filename of the most recent backup (they are named with a timestamp)
latest_backup="$(find '/root/backups' -maxdepth 1 -type f -name '*.xz' -print | sort -r | head -n1)"

# only restore if a backup was found
if [ -n "$latest_backup" ]; then
    # create a temporary file to hold the decompressed backup
    temp_file=$(mktemp -p /tmp/ -t webinoly_backup.XXXXXX)
    # decompress the backup
    xz -dc "$latest_backup" >"$temp_file"
    # restore the webinoly configuration
    webinoly -backup=local -import=full -file="$temp_file"
    # remove the temporary file
    rm "$temp_file"
fi

#!/bin/sh

# ensure the script exits on error
set -e

# get the filename for selected file defaulting to the most recent backup (they are named with a timestamp)
selected_backup="${1:-"$(find '/root/backups' -maxdepth 1 -type f -name '*.xz' -print | sort -r | head -n1)"}"

echo "About to restore \"$selected_backup\". Press ENTER to continue or Ctrl-C to escape."
read -r useless_user_input

# only restore if a backup was found
if [ -n "$selected_backup" ]; then
    # create a temporary file to hold the decompressed backup
    temp_file=$(mktemp -p /tmp/ -t webinoly_backup.XXXXXX)
    # decompress the backup
    xz -dc "$selected_backup" >"$temp_file"
    # restore the webinoly configuration
    webinoly -backup=local -import=full -file="$temp_file"
    # remove the temporary file
    rm "$temp_file"
fi

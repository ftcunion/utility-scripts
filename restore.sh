#!/bin/sh

# ensure the script exits on error
set -e

# function to restore a tar archive from zbackup, returning filename
restore_tar_archive() {
	# exit if $1 is not defined
	[ -z "$1" ] && exit 1

	# variables
	zbackup_path="$1"
	output_path="/root/backups/$(basename "$zbackup_path")"

	# if /root/backups does not exist, create it
	[ ! -d "/root/backups" ] && mkdir -p "/root/backups"

	# restore the tar archive using zbackup
	zbackup restore --non-encrypted "$zbackup_path" >"$output_path"
	echo "$output_path"
}

# if $1 is specified and file says it is a tar archive, then use it
if [ -n "$1" ] && [ "$(file -b --mime-type "$1")" = "application/x-tar" ]; then
	selected_backup="$1"
elif [ -n "$1" ]; then
	selected_backup="$(restore_tar_archive "$1")"
else
	# try to guess!
	# find the most recent month, (though having more than one month is an edge case)
	most_recent_month="$(find '/root/backups/webinoly' -maxdepth 1 -mindepth 1 -type d ! -name '.*' -print0 | sort -rz | head -z --lines=1 | tr -d '\0')"

	# if most recent month is empty and no backup is specified, exit
	if [ -z "$most_recent_month" ]; then
		echo "No backup found to restore."
		exit 1
	fi

	# get the filename for selected file defaulting to the most recent backup (they are named with a timestamp)
	selected_zbackup="$(find "$most_recent_month/backups" -maxdepth 1 -type f ! -name '.*' -print0 | sort -rz | head -z --lines=1 | tr -d '\0')"

	# otherwise, find the most recent backup
	selected_backup="$(restore_tar_archive "$selected_zbackup")"
fi

echo "About to restore \"$selected_backup\". Press ENTER to continue or Ctrl-C to escape."
read -r _

# restore the webinoly configuration
webinoly -backup=local -import=full -file="$selected_backup"

# utility-scripts

This repository contains scripts to backup and restore backups on a server running [webinoly](https://github.com/QROkes/webinoly). There are currently two scripts available:

1. `backup.sh` - This script is not interactive and will backup the webinoly server to `/root/backups`. This script uses webinoly's backup feature, but it compresses the backups, deletes backups older than 3 days, and syncs the files to Google Drive. It is intended to be run daily via a cron job.
2. `restore.sh` - This script is interactive and will restore a backup from `/root/backups` to the webinoly server. It will restore the most recent backup by default, but you can specify a different backup to restore by providing the backup archive as an argument. This script is intended to be run manually when needed and will prompt the user to confirm before restoring a backup.

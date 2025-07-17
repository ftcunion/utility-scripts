# utility-scripts

This repository contains scripts to backup and restore backups on a server running [webinoly](https://github.com/QROkes/webinoly). There are currently four scripts available:

1. `setup/install.sh` - This script installs webinoly, configures some default options, and installs plugins. The script must be run twice. Between the two runs, the user should complete the initial setup wizard on the WordPress site.
2. `setup/hardening.sh` - This script blocks direct access to the web server and whitelists Cloudflare IPs. It is intended to be run sometime after the initial setup of the web server.
3. `backup.sh` - This script is not interactive and will backup the webinoly server to `/root/backups`. This script uses webinoly's backup feature, but it compresses the backups, deletes backups older than 3 days, and syncs the files to Google Drive. It is intended to be run daily via a cron job.
4. `restore.sh` - This script is interactive and will restore a backup from `/root/backups` to the webinoly server. It will restore the most recent backup by default, but you can specify a different backup to restore by providing the backup archive as an argument. This script is intended to be run manually when needed and will prompt the user to confirm before restoring a backup.

## Notes

### PSK Alternative to mTLS

One alternative to mTLS in the hardening script is to use a preshared key. It is not as secure as mTLS, but it is easier to set up. You can set this up by adding the following to a file named `preshared-key-nginx.conf` in the `/var/www/$DOMAIN/` directory:

```nginx
if ($http_x_preshared_key != "YOUR_KEY_DO_NOT_JUST_PASTE_THIS") {
  return 444;
}
```

and then adding a Request Header Transform Rule in Cloudflare to add the header `x-preshared-key` with the value of the key (`YOUR_KEY_DO_NOT_JUST_PASTE_THIS` in the example above). This will drop all requests that do not have the correct header.

Off-topic side note. This is usually the only method that works on shared hosting. In apache/litespeed, you can enforce the preshared key by adding the following to the `.htaccess` file in the web root:

```apache
# BEGIN Cloudflare Pre-shared Key
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteCond %{HTTP:x-preshared-key} !^YOUR_KEY_DO_NOT_JUST_PASTE_THIS$
  RewriteRule ^ - [F]
</IfModule>
# END Cloudflare Pre-shared Key
```

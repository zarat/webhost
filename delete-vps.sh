#!/bin/bash

# delete the system user
# kill all his processes (logins)
pkill -u $1 > /dev/null
# prevent user from log in
usermod -L $1 > /dev/null
# delete account
deluser --remove-home $1
# remove home directory (just to make sure)
rm -rf /home/$1

# remove sshd config file (ssh redirect)
rm -rf /etc/ssh/sshd_config.d/$1.conf

# stop and remove the vps
ssh root@192.168.0.100 "pct stop $2"
ssh root@192.168.0.100 "pct destroy $2"

# revoke certificate
certbot revoke --cert-path /etc/letsencrypt/live/$1.zarat.at/fullchain.pem --non-interactive --agree-tos > /dev/null 2>&1
# delete certificate
certbot delete --cert-name $1.zarat.at --non-interactive --quiet > /dev/null 2>&1
# delete files
rm -rf /etc/letsencrypt/live/$1.zarat.at*

# remove reverse proxy config
rm -rf /etc/nginx/sites-enabled/$1.conf
rm -rf /etc/nginx/sites-available/$1.conf

echo "Account '$1' wurde erfolgreich entfernt."

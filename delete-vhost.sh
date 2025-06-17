#!/bin/bash

user=$1

pkill -u $1 > /dev/null
usermod -L $1 > /dev/null
deluser $1 > /dev/null

rm -rf /home/$1 > /dev/null

rm -rf /etc/nginx/sites-enabled/$1.conf > /dev/null
rm -rf /etc/nginx/sites-available/$1.conf > /dev/null

docker rm -f $1 > /dev/null

certbot revoke --cert-path /etc/letsencrypt/live/$1.zarat.at/fullchain.pem --non-interactive --agree-tos > /dev/null 2>&1
certbot delete --cert-name $1.zarat.at --non-interactive --quiet > /dev/null 2>&1
rm -rf /etc/letsencrypt/live/$1.zarat.at > /dev/null

systemctl reload vsftpd
nginx -s reload

rm -rf /etc/ssh/sshd_config.d/$1.conf
systemctl restart ssh

echo "Konto $1 wurde entfernt."

#!/bin/bash

user=$1

pkill -u $1
usermod -L $1
deluser $1

rm -rf /home/$1

rm -rf /etc/nginx/sites-enabled/$1.conf
rm -rf /etc/nginx/sites-available/$1.conf

docker rm -f $1

rm -rf /etc/letsencrypt/live/$1.zarat.at

systemctl reload vsftpd
nginx -s reload

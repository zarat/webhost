#!/bin/bash

# get installed php-fpm version
phpsvc=$(service --status-all 2>/dev/null | grep -o 'php[0-9.]*-fpm')

# start all services
service ssh start
service nginx start
service mariadb start
service $phpsvc start

# enable all services at startup
systemctl enable ssh
systemctl enable nginx
systemctl enable myriadb
systemctl enable $phpsvc

# keep it busy
tail -f /dev/null

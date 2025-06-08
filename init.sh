#!/bin/bash

# frage nach default domain
read -p "Webhost domain: " domain

# update system
apt update

# install curl
apt install -y curl

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# install nginx
apt install nginx -y

# install certbot, nginx-plugin
apt install python3-certbot-nginx -y

# install vsftpd
apt install vsftpd -y

# configure vsftpd
vsftpd_config_file="/etc/vsftpd.conf"
cat > "$vsftpd_config_file" <<EOF
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
allow_writeable_chroot=YES
EOF

# configure default vhost
default_host_conf="/etc/nginx/sites-available/default"
cat > "$default_host_conf" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;

    server_name $domain;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# set permissions
chmod 755 /var/www/html
chown -R www-data:www-data /var/www/html

# get certificate for root domain
certbot --nginx -d $domain --non-interactive --agree-tos -m admin@$domain

# make default website
echo <h1>It works</h1><p>This is the default website</p> > /var/www/html/index.html

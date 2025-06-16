#!/bin/bash

# frage nach default domain
read -p "Webhost domain (ohne www): " domain

# update system
apt update

# install openssl
apt install -y openssl curl msmtp

touch ~/.msmtprc

cat > ~/.msmtprc <<EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile ~/.msmtp.log

account gmail
host smtp.gmail.com
port 587
from dein.email@gmail.com
user dein.email@gmail.com
password dein_passwort

account default : gmail
EOF

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh 
sh get-docker.sh 
rm get-docker.sh

# create default mac vlan
echo '[info] set up default macvlan'
read -p 'Please specify subnet (CIDR): ' macvlan_subnet
read -p 'Please specify the gateway (IP): ' macvlan_gateway
available_interfaces=$(ls /sys/class/net | grep -v lo | tr '\n' ' ')
echo "Available interfaces: $available_interfaces"
read -p 'Please specify the interface: ' macvlan_device
docker network create -d macvlan --subnet=$macvlan_subnet --gateway=$macvlan_gateway -o parent=$macvlan_device macvlan_net

# install nginx
apt install nginx php8.1-fpm -y

# install certbot, nginx-plugin
apt install python3-certbot-nginx -y

# install vsftpd
apt install vsftpd -y

# configure vsftpd
vsftpd_config_file="/etc/vsftpd.conf"
cat > "$vsftpd_config_file" <<EOF
listen=YES
listen_ipv6=NO
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

    root /var/www/html;
    index index.php index.html index.htm;

    server_name $domain www.$domain;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
    
}
EOF

# set permissions
chmod 755 /var/www/html
chown -R www-data:www-data /var/www/html

# get certificate for root domain
#certbot --nginx -d $domain --non-interactive --agree-tos -m admin@$domain
read -p "Möchten Sie jetzt ein Zertifikat fuer die Root-Domain anfordern? (j/n): " antwort

case "$antwort" in
    [jJ])
        certbot --nginx -d $domain --non-interactive --agree-tos -m admin@$domain
        ;;
    [nN])
        echo "Lege kein Root Domain Zertifikat an."
        ;;
    *)
        echo "Ungültige Eingabe. Bitte j oder n eingeben."
        ;;
esac

# make default website
# echo "<h1>It works</h1><p>This is the default website</p>" > /var/www/html/index.html
rm /var/www/html/index*
cp templates/index.php /var/www/html
chown www-data:www-data /var/www/html/index.php

echo "Dont forget to update '~/.msmtprc' with your smtp settings."

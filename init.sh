#!/bin/bash

# frage nach default domain
read -p "Webhost domain (ohne www): " domain

# update system
apt update > /dev/null 2>&1

export DEBIAN_FRONTEND=noninteractive

# install packages
echo "Installiere erforderliche Packages"
apt install -y openssl curl msmtp jq > /dev/null 2>&1
echo "Installiere Intrusion Detection (Fail2Ban)"
apt install -y fail2ban > /dev/null 2>&1

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
echo "Installiere Docker"
curl -fsSL https://get.docker.com -o get-docker.sh > /dev/null 2>&1
sh get-docker.sh > /dev/null 2>&1
rm get-docker.sh

# create default mac vlan
#echo '[info] set up default macvlan'
#read -p 'Please specify subnet (CIDR): ' macvlan_subnet
#read -p 'Please specify the gateway (IP): ' macvlan_gateway
#available_interfaces=$(ls /sys/class/net | grep -v lo | tr '\n' ' ')
#echo "Available interfaces: $available_interfaces"
#read -p 'Please specify the interface: ' macvlan_device
#docker network create -d macvlan --subnet=$macvlan_subnet --gateway=$macvlan_gateway -o parent=$macvlan_device macvlan_net

# install nginx
echo "Installiere NginX"
apt install nginx php8.1-fpm -y > /dev/null 2>&1

# install php
echo "Installiere PHP"
apt install php8.1-fpm -y > /dev/null 2>&1

# install certbot, nginx-plugin
echo "Installiere Certbot NginX Plugin"
apt install python3-certbot-nginx -y > /dev/null 2>&1

# install vsftpd
echo "Installiere Vsftpd"
apt install vsftpd -y > /dev/null 2>&1

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

touch "/etc/sudoers.d/www-data-script"
SUDOERS_FILE="/etc/sudoers.d/www-data-script"
FIRST_SUDOERS_LINE="www-data ALL=(ALL) NOPASSWD: /root/webhost/create-vhost.sh"
if ! grep -Fxq "$FIRST_SUDOERS_LINE" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$FIRST_SUDOERS_LINE" > "$SUDOERS_FILE"
fi
SECOND_SUDOERS_LINE="www-data ALL=(ALL) NOPASSWD: /root/webhost/create-vps.sh"
if ! grep -Fxq "$SECOND_SUDOERS_LINE" "$SUDOERS_FILE" 2>/dev/null; then
    echo "$SECOND_SUDOERS_LINE" >> "$SUDOERS_FILE"
fi
chmod 440 "$SUDOERS_FILE"

# get certificate for root domain
#certbot --nginx -d $domain --non-interactive --agree-tos -m admin@$domain
read -p "Möchten Sie jetzt ein Zertifikat fuer die Root-Domain anfordern? (j/n): " antwort

case "$antwort" in
    [jJ])
        certbot --nginx -d $domain -d www.$domain --non-interactive --agree-tos -m admin@$domain
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

nginx -s reload

chmod +x /root/webhost/create-vhost.sh
chmod +x /root/webhost/create-vps.sh

read -p "Möchten Sie die vHost Images jetzt erstellen (j/n): " make_images

case "$make_images" in
    [jJ])
        cd images
        bash make.sh
        ;;
    [nN])
        ;;
    *)
        echo "Ungültige Eingabe. Bitte j oder n eingeben."
        ;;
esac

cat >> /etc/ssh/sshd_config <<EOF
Match User *
    AllowTcpForwarding yes
    PermitTunnel no
    PermitTTY no
    X11Forwarding no
    ForceCommand echo 'This account is restricted to port forwarding only.'
EOF

echo "Include /etc/ssh/sshd_config.d/*.conf" >> /etc/ssh/sshd_config

mkdir /srv/customers

ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
read -p "IP deines PVE: " pveip
ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@$pveip > /dev/null 2>&1

echo "Fertig! Passe das PVE Passwort in der Datei create-vps.sh an!"
echo "Passe die SMTP Zugangsdaten in '~/.msmtprc' an!"

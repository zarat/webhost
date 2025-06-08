#!/bin/bash

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# install nginx
apt install nginx -y

# install certbot, nginx-plugin
apt install python3-nginx-plugin -y

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

# Done

#!/bin/bash
user=$1

# add system user
useradd -m $1
usermod -aG www-data $1

# set default password
echo "$1:password" | chpasswd

# reload vsftpd
systemctl reload vsftpd

# create user dir
mkdir -p /home/$1/public_html
chmod 755 /home/$1
chmod 775 /home/$1/public_html
chown -R $1:$1 /home/$1

chown -R www-data:$1 /home/$1/public_html

# choose image
read -p 'Choose an image (ubuntu1804php72, ubuntu2204php81, ubuntu2404php83): ' containerimage

# start container
# docker run -dit --name $user --restart=always -v /home/$user/public_html:/var/www/html --network macvlan_net --ip=192.168.0.2 $containerimage
docker run -dit --name $user --restart=always -v /home/$user/public_html:/var/www/html $containerimage

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

vhost_file="/etc/nginx/sites-available/$user.conf"

cat > "$vhost_file" <<EOF
server {
    listen 80;
    server_name $user.zarat.at;

    location / {
        proxy_pass http://$container_ip;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -s "$vhost_file" /etc/nginx/sites-enabled/

nginx -s reload

certbot --nginx -d $user.zarat.at --non-interactive --agree-tos -m manuel@zarat.at

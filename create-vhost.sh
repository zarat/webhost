#!/bin/bash
user=$1

# add system user
useradd -m $1

# set default password
echo "$1:password" | chpasswd

# reload vsftpd
systemctl reload vsftpd

# create user dir
mkdir -p /home/$1/public_html
chmod 755 /home/$1
chmod 755 /home/$1/public_html
chown -R $1:$1 /home/$1

# start container
docker run -dit --name $user --restart=always -v/home/$user/public_html:/usr/local/apache2/htdocs httpd

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

vhost_file="/etc/nginx/sites-available/$user.conf"

cat > "$vhost_file" <<EOF
server {
    listen 80;
    server_name $user.zarat.at;

    location / {
        proxy_pass http://$container_ip;
    }
}
EOF

ln -s "$vhost_file" /etc/nginx/sites-enabled/

nginx -s reload

certbot --nginx -d $user.zarat.at --non-interactive --agree-tos -m manuel@zarat.at

#!/bin/bash
echo "[info] Adding new user '$1'"
user=$1

# add system user
useradd -m $1
usermod -aG www-data $1

echo "[info] Generating random password"
# generate random password for ftp and mysql root user
password=$(openssl rand -base64 8)

echo "[info] Changing password of user"
# set default password
echo "$1:$password" | chpasswd

echo "[info] Reloading vsftpd"
# reload vsftpd
systemctl reload vsftpd

echo "[info] Creating folder structure and setting permissions for vhost /home/$1"
# create user dir
mkdir -p /home/$1/public_html
chmod 755 /home/$1
chmod 775 /home/$1/public_html
chown -R $1:$1 /home/$1

chown -R www-data:$1 /home/$1/public_html

# choose image
# read -p 'Choose an image (ubuntu1804php72, ubuntu2204php81, ubuntu2404php83): ' containerimage
containerimage="ubuntu2404php83"
echo "[info] Using image $containerimage"

echo "[info] Starting container"
docker run -dit --name $user --restart=always -v /home/$user/public_html:/var/www/html $containerimage > /dev/null

echo "[info] Starting services in container"
docker exec "$user" bash -c "service nginx start" > /dev/null
docker exec "$user" bash -c "/etc/init.d/mariadb start" > /dev/null
docker exec "$user" bash -c "service php8.3-fpm start" > /dev/null

echo "[info] Changing mysql root password"
# change mysql root password
docker exec "$user" bash -c "mysql -u root -e \"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;
\""

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

echo "[info] Generating vhost configuration"
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

echo "[info] Reloading nginx"
nginx -s reload

echo "[info] Requesting LetsEncrypt certificate for $1.zarat.at"
certbot --nginx -d $user.zarat.at --non-interactive --agree-tos -m manuel@zarat.at > /dev/null

echo "User: $user"
echo "Password: $password"

#!/bin/bash
#echo "[info] Adding new user '$1'"
user=$1
email=$2

quit=0

if id $1 &>/dev/null; then
    # echo "Dieser Benutzer existiert bereits."
    quit=1 # exit
fi

if docker ps -a --format '{{.Names}}' | grep -w $1 > /dev/null; then
    # echo "Container $1 existiert bereits."
    quit=1 # exit
fi

if [ $quit -eq 1 ]; then
    echo "Ooops, bitte wähle einen anderen Namen."
    exit
fi

# add system user
useradd -m $1
usermod -aG www-data $1

# prevent ssh login
# nope, this also prevents ftp login
# usermod -s /usr/sbin/nologin $1

#echo "[info] Generating random password"
# generate random password for ftp and mysql root user
password=$(openssl rand -base64 8)

#echo "[info] Changing password of user"
# set default password
echo "$1:$password" | chpasswd

#echo "[info] Reloading vsftpd"
# reload vsftpd
systemctl reload vsftpd

#echo "[info] Creating folder structure and setting permissions for vhost /home/$1"
# create user dir
mkdir -p /home/$1/public_html
chmod 755 /home/$1
chmod 775 /home/$1/public_html
chown -R $1:$1 /home/$1

chown -R www-data:$1 /home/$1/public_html

# choose image
# read -p 'Choose an image (ubuntu1804php72, ubuntu2204php81, ubuntu2404php83): ' containerimage
containerimage="ubuntu2404php83"
#echo "[info] Using image $containerimage"

#echo "[info] Starting container"
docker run -dit --name $user --restart=always -v /home/$user/public_html:/var/www/html $containerimage > /dev/null

docker exec "$user" bash -c "echo 'root:$password' | chpasswd"
docker exec "$user" bash -c "service ssh start"

#echo "[info] Starting services in container"
docker exec "$user" bash -c "service nginx start" > /dev/null
docker exec "$user" bash -c "/etc/init.d/mariadb start" > /dev/null
docker exec "$user" bash -c "service php8.3-fpm start" > /dev/null

#echo "[info] Changing mysql root password"
# change mysql root password
docker exec "$user" bash -c "mysql -u root -e \"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;
\""

docker exec "$user" bash -c "echo '<h1>Dieser Webspace ist reserviert</h1><p>In K&uuml;rze entsteht hier eine neue Website.</p>' > /var/www/html/index.html" 

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

#echo "[info] Generating vhost configuration"
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

#echo "[info] Reloading nginx"
nginx -s reload

#echo "[info] Requesting LetsEncrypt certificate for $1.zarat.at"
certbot --nginx -d $user.zarat.at --non-interactive --agree-tos -m manuel@zarat.at 1> /dev/null 2>/dev/null

echo "Wir haben deine Zugangsdaten an $email gesendet."

TO="$email"
SUBJECT="Dein kostenloser Webspace"
BODY=$(cat <<EOF
Hallo $user, dein kostenloser Webspace wurde eingerichtet.

Host: https://$user.zarat.at

FTP:
    Host: $user.zarat.at
    User: $user
    Password: $password

MySQL:
    Host: localhost
    User: root
    Password: $password

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password
    Connection-String: ssh -J $user@$user.zarat.at root@$container_ip
EOF
)
echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO"

TO="manuel.zarat@gmail.com"
SUBJECT="Ein neuer Webspace ($user) wurde eingerichtet"
BODY=$(cat <<EOF
Ein kostenloser Webspace wurde eingerichtet.

Email: $email

Host: https://$user.zarat.at

FTP:
    Host: $user.zarat.at
    User: $user
    Password: $password

MySQL:
    Host: localhost
    User: root
    Password: $password
EOF
)

echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO"

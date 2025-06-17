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

if [ -f /etc/nginx/sites-available/$1.conf ]; then
    # echo "Konfigurationsdatei existiert bereits."
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

# generate key pair
sudo -u $1 ssh-keygen -t rsa -b 4096 -f /home/$1/.ssh/id_rsa -N "" -q

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
#mkdir -p /home/$1/public_html
#chmod 755 /home/$1
#chmod 775 /home/$1/public_html
#chown -R $1:$1 /home/$1
#chown -R www-data:$1 /home/$1/public_html

dd if=/dev/zero of=/srv/customers/$1.img bs=1M count=1024 > /dev/null 2>&1
mkfs.ext4 /srv/customers/$1.img > /dev/null 2>&1
mkdir -p /home/$1/public_html
#mount -o loop /srv/customers/$1.img /home/$1/public_html
chmod 755 /home/$1
chmod 775 /home/$1/public_html
chown -R $1:$1 /home/$1
chown -R www-data:$1 /home/$1/public_html
#mount -o loop /srv/customers/$1.img /home/$1/public_html

# choose image
image_list=$(docker image ls --format '{{.Repository}}' | sed -E 's/ubuntu([0-9]{2}).*/ubuntu\1/' | sort -u | paste -sd,)
read -p 'Choose an image ($image_list): ' containerimage
# containerimage="ubuntu2404php83"
#echo "[info] Using image $containerimage"

if ! docker image ls -q "$containerimage" | grep -q .; then
    echo "Container-Image '$containerimage' existiert nicht."
    exit 1
fi

#echo "[info] Starting container"
docker run -dit --name $user --restart=always -v /home/$user/public_html:/var/www/html $containerimage > /dev/null

docker exec "$user" bash -c "echo 'root:$password' | chpasswd"

#echo "[info] Changing mysql root password"
service mariadb start > /dev/null 2>&1
docker exec "$user" bash -c "mysql -u root -e \"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$password';
FLUSH PRIVILEGES;
\""

docker exec "$user" bash -c "echo '<h1>Dieser Webspace ist reserviert</h1><p>In K&uuml;rze entsteht hier eine neue Website.</p>' > /var/www/html/index.html" 

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

# copy key pair to container
cat /home/$1/.ssh/id_rsa.pub | docker exec -i $1 sh -c 'mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && chmod 700 /root/.ssh'

# add to sshd_config
cat >> "/etc/ssh/sshd_config.d/$1.conf" <<EOF
Match User $1
    AllowTcpForwarding no
    PermitTunnel no
    PermitTTY no
    X11Forwarding no
    ForceCommand echo "SSH Login ist für diesen Account gesperrt." # ForceCommand /usr/bin/ssh -i /home/$1/.ssh/id_rsa -o StrictHostKeyChecking=no root@$container_ip
EOF
systemctl restart ssh > /dev/null

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
SUBJECT="Dein Webserver ist bereit ($user.zarat.at)"
BODY=$(cat <<EOF
Hallo $user, dein kostenloser Webserver wurde eingerichtet.

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
EOF
)
echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1

TO="manuel.zarat@gmail.com"
SUBJECT="Ein neuer Webserver ($user) wurde eingerichtet"
BODY=$(cat <<EOF
Ein kostenloser Webserver wurde eingerichtet.

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

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password
EOF
)

echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1

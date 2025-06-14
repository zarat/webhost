#!/bin/bash
user=$1

read -p 'Please specify the users domain: ' user_domain

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

# start container
read -p "Welches Image soll genutzt werden? (h [http] / p [php/mysql]): " antwort
case "$antwort" in
    [h])
        docker run -dit --name $user --restart=always -v/home/$user/public_html:/usr/local/apache2/htdocs httpd
        ;;
    [p])
        docker run -dit --name $user --restart=always -v/home/$user/public_html:/var/www/html custom_lamp
        ;;
    *)
        echo "Ungültige Eingabe. Bitte j oder n eingeben."
        ;;
esac
#docker run -dit --name $user --restart=always -v/home/$user/public_html:/usr/local/apache2/htdocs httpd
#docker run -dit --name $user --restart=always -v/home/$user/public_html:/var/www/html custom_lamp

container_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$user")

vhost_file="/etc/nginx/sites-available/$user.conf"

cat > "$vhost_file" <<EOF
server {
    listen 80;
    server_name $user.$user_domain;

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

certbot --nginx -d $user.$user_domain --non-interactive --agree-tos -m $user@$user_domain

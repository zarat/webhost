FROM ubuntu:18.04
ARG DEBIAN_FRONTEND=noninteractive
RUN ln -snf /usr/share/zoneinfo/Europe/Vienna /etc/localtime && echo Europe/Vienna > /etc/timezone
RUN dpkg --configure -a
RUN apt update && apt install -y nginx php7.2-fpm mariadb-server php-mysqli ssh
RUN cat <<'EOF' > /etc/nginx/sites-available/default
server {
        listen 80 default_server;
        listen [::]:80 default_server;
        root /var/www/html;
        index index.php index.html index.htm index.nginx-debian.html;
        server_name _;
        location / {
                try_files $uri $uri/ =404;
        }
        location ~ \.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/run/php/php7.2-fpm.sock;
        }
        location ~ /\.ht {
               deny all;
        }
}
EOF
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
COPY start.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

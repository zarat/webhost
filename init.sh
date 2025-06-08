#!/bin/bash

# install docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# install nginx
apt install nginx

# install certbot, nginx-plugin
apt install python3-nginx-plugin

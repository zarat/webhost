#!/bin/bash

deluser $1
rm -rf /home/$1
rm -rf /etc/ssh/sshd_config.d/$1.conf
ssh root@192.168.0.100 "pct stop $2"
ssh root@192.168.0.100 "pct destroy $2"

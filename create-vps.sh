#!/bin/bash

if [[ "$1" =~ ^[a-zA-Z0-9]+$ ]]; then
    echo "" > /dev/null 
else
    echo "Bitte nur folgende Zeichen verwenden: a-z A-Z 0-9"
    exit 1
fi

if id $1 &>/dev/null; then
    echo "Ooops, bitte wähle einen anderen Namen."
    exit 1
fi

# ===== KONFIGURATION =====
PVE_HOST="192.168.0.100"         # IP oder Hostname deines Proxmox-Servers
PVE_USER="root@pam"             # API-Benutzer (z. B. root@pam oder apiuser@pve)
PVE_PASS="Lunikoff0310#"        # Passwort oder API-Token
PVE_NODE="pve"                  # Name des Proxmox-Nodes (z. B. pve)

# VMID=150
HOSTNAME=$1
TEMPLATE="local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
MEMORY=512                     # MB
CORES=1
DISK_SIZE=1                    # GB
ROOT_PASS=$(openssl rand -base64 8)

EMAIL="$2"

# ===== LOGIN (Ticket holen) =====
#echo "[*] Authentifiziere bei Proxmox API..."
AUTH_RESPONSE=$(curl -sk -d "username=$PVE_USER&password=$PVE_PASS" https://$PVE_HOST:8006/api2/json/access/ticket)

TICKET=$(echo "$AUTH_RESPONSE" | jq -r '.data.ticket')
CSRF=$(echo "$AUTH_RESPONSE" | jq -r '.data.CSRFPreventionToken')

if [[ -z "$TICKET" || -z "$CSRF" ]]; then
  echo "[!] Fehler: Authentifizierung fehlgeschlagen."
  exit 1
fi

#echo "[*] Suche nach erster freier VMID auf Node $PVE_NODE..."
USED_VMIDS=$(curl -sk -b "PVEAuthCookie=$TICKET" https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc | jq '.data[].vmid')

USED_ARRAY=($(echo "$USED_VMIDS"))

VMID=150
while [[ " ${USED_ARRAY[@]} " =~ " $VMID " ]]; do
  ((VMID++))
done

#echo "[+] Verwende VMID $VMID"

IPCONFIG_INTERFACE="name=eth0"
IPCONFIG_BRIDGE="bridge=vmbr0"
IPCONFIG="ip=192.168.0.$VMID/24,gw=192.168.0.1"


# ===== LXC erstellen =====
#echo "[*] Erstelle LXC-Container $VMID auf Node $PVE_NODE..."

CREATE_RESPONSE=$(curl -sk -X POST https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc \
  -H "CSRFPreventionToken: $CSRF" \
  -b "PVEAuthCookie=$TICKET" \
  -d vmid=$VMID \
  -d hostname=$HOSTNAME \
  -d ostemplate=$TEMPLATE \
  -d memory=$MEMORY \
  -d cores=$CORES \
  -d rootfs="local-lvm:${DISK_SIZE}" \
  -d password="lunikoff" \
  -d unprivileged=1)

# echo "$CREATE_RESPONSE" | jq


# ===== Container starten =====
# echo "[*] Starte Container $VMID..."
answer=$(curl -sk -X POST https://$PVE_HOST:8006/api2/json/nodes/$PVE_NODE/lxc/$VMID/status/start \
  -H "CSRFPreventionToken: $CSRF" \
  -b "PVEAuthCookie=$TICKET" | jq)

sleep 15

ssh root@$PVE_HOST "pct exec $VMID -- bash -c 'useradd -m $HOSTNAME -G sudo -s /bin/bash'"
ssh root@$PVE_HOST "pct exec $VMID -- bash -c 'echo $HOSTNAME:$ROOT_PASS | chpasswd'"
ssh root@$PVE_HOST "pct set $VMID -net0 $IPCONFIG_INTERFACE,$IPCONFIG_BRIDGE,$IPCONFIG"

useradd -m $HOSTNAME
echo "$HOSTNAME:$ROOT_PASS" | chpasswd

# generate key
sudo -u $HOSTNAME ssh-keygen -t rsa -b 4096 -f /home/$HOSTNAME/.ssh/id_rsa -N "" -q

# copy key to container
ssh-copy-id -i /home/$HOSTNAME/.ssh/id_rsa.pub -o StrictHostKeyChecking=no $HOSTNAME@192.168.0.120 > /dev/null 2>&1

# add to sshd_config
cat >> "/etc/ssh/sshd_config.d/$HOSTNAME.conf" <<EOF
Match User $HOSTNAME
    AllowTcpForwarding no
    PermitTunnel no
    PermitTTY yes
    X11Forwarding no
    ForceCommand /usr/bin/ssh -i /home/$HOSTNAME/.ssh/id_rsa -o StrictHostKeyChecking=no $HOSTNAME@192.168.0.$VMID
EOF
systemctl restart ssh

# echo "[✓] Container $VMID wurde erstellt und gestartet."

user=$HOSTNAME
password=$ROOT_PASS
email=$EMAIL

TO="$email"
SUBJECT="Dein VPS ist bereit ($user.zarat.at)"
BODY=$(cat <<EOF
Hallo $user, dein VPS wurde eingerichtet.

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password

Hinweis: Da die SSH Verbindung über einen Jump-Host geleitet wird, musst du das Passwort beim Login 2mal eingeben. B ei Fragen, Problemen und Beschwerden sende uns bitte eine Mail an support@zarat.at. Viel Spass mit deinem neuen Webserver.
EOF
)
echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1

TO="manuel.zarat@gmail.com"
SUBJECT="Ein VPS ($user) wurde eingerichtet"
BODY=$(cat <<EOF
Ein VPS wurde eingerichtet.

Email: $email

SSH:
    Host: $user.zarat.at
    User: $user
    Password: $password
EOF
)

echo -e "Subject: $SUBJECT\nFrom: manuel@zarat.at\nTo: $TO\n\n$BODY" | msmtp "$TO" > /dev/null 2>&1

echo "Wir haben deine Zugangsdaten an $email gesendet."



vhost_file="/etc/nginx/sites-available/$user.conf"
cat > "$vhost_file" <<EOF
server {
    listen 80;
    server_name $user.zarat.at;

    location / {
        proxy_pass http://192.168.0.$VMID;
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

certbot --nginx -d $user.zarat.at --non-interactive --agree-tos -m manuel@zarat.at 1> /dev/null 2>/dev/null

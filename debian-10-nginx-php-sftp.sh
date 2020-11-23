#!/bin/bash

# ARE WE COOL ENOUGH?

if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

# GET ARGS

while [ $# -gt 0 ]; do
  case "$1" in
    --domain=*)
      DOMAIN="${1#*=}"
      ;;
    --username=*)
      USERNAME="${1#*=}"
      ;;
    *)
      printf "***************************\n"
      printf "* Error: Invalid argument.*\n"
      printf "***************************\n"
      exit 1
  esac
  shift
done

# VALIDATE VARS
if [ -z "$DOMAIN" ]; then
  echo "--domain is required"
  exit
fi

if [ -z "$USERNAME" ]; then
  echo "--user is required"
  exit
fi

# INSTALL SOME STUFF

apt update
apt-get install -y nginx php-fpm php-curl

# DO WE HAVE UFW?

if type "ufw" > /dev/null; then
  ufw allow 'Nginx HTTP'
fi

# ADD USER
PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 13 ; echo '')

groupadd sftp_users
useradd -d /home/$USERNAME -G sftp_users -s /bin/bash $USERNAME
mkdir -p /home/$USERNAME
chown $USERNAME:$USERNAME /home/$USERNAME
echo -e "$PASSWORD\n$PASSWORD" | passwd $USERNAME
echo "PASSWORD for $USERNAME: $PASSWORD"

# SETUP SFTP

# assuming only one line starts with Subsystem
sed -e '/Subsystem/ s/^#*/#/' -i /etc/ssh/sshd_config
cat sshd_config_appenditure >> /etc/ssh/sshd_config

# SETUP NGINX
mkdir -p /var/www/$DOMAIN

cp nginx-basic.conf /etc/nginx/sites-available/$DOMAIN
sed -i "s/DOMAIN/$DOMAIN/g" "/etc/nginx/sites-available/$DOMAIN"
ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN

# COPY DEMO FILE
cp phpinfo.php /var/www/$DOMAIN/index.php

# FIX PERMISSIONS
chown -R $USERNAME:$USERNAME /var/www/$DOMAIN

# RESTART SERVICES
systemctl restart ssh
systemctl reload nginx


echo "All done"


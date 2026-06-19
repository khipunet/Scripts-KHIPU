#!/bin/bash

# Generador de VirtualHost para OJS con detección dinámica de PHP
# Se eliminó la instalación de MariaDB/MySQL para conexión externa
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root."
  exit
fi

# 1. Detección dinámica de la versión de PHP
php_ver=$(php -r "echo PHP_MAJOR_VERSION . '.' . PHP_MINOR_VERSION;" 2>/dev/null)
if [ -z "$php_ver" ]; then
    echo "No se detectó PHP instalado. Instalando versión por defecto (8.2)..."
    php_ver="8.2"
    sudo apt install -y php8.2-fpm
else
    echo "Versión de PHP detectada: $php_ver"
fi

echo "--- Instalando Nginx, PHP$php_ver-fpm y Certbot ---"
sudo apt update
sudo apt install -y nginx php${php_ver}-fpm certbot python3-certbot-nginx

read -p "Nombre del usuario (para la ruta /var/www/username): " username
read -p "Dominio o IP del servidor: " domain
read -p "Puerto de escucha (Host, ej. 80 o 8080): " listen_port
read -p "Puerto interno de servicio (ej. 80 o 443): " internal_port

vhost_file="/etc/nginx/sites-available/$domain"

# Configuración del bloque server usando la versión detectada
cat <<EOF > $vhost_file
server {
    listen $listen_port;
    server_name $domain;
    root /var/www/$username;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${php_ver}-fpm.sock;
    }
}
EOF

# Habilitar el sitio
ln -sf $vhost_file /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# SSL automático
if [ "$internal_port" == "443" ]; then
    echo "--- Solicitando certificado SSL para $domain ---"
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m webmaster@khipu.net
fi

# Ajustar permisos
sudo chown -R www-data:www-data /var/www/$username
sudo chmod -R 775 /var/www/$username

echo "Configuración aplicada exitosamente."
echo "Sitio disponible en http://$domain:$listen_port"
EOF
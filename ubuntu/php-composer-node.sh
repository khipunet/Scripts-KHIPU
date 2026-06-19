#!/bin/bash

# Verificar que se ejecute como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)."
  exit
fi

echo "--- Configuración de Usuario ---"
while true; do
    read -p "Nombre del nuevo usuario (solo alfanumérico, guiones bajos o medios): " username
    if [[ "$username" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$ ]]; then
        break
    else
        echo "Error: Nombre de usuario inválido."
    fi
done

read -s -p "Contraseña para $username: " password
echo ""

# Crear usuario
if id "$username" &>/dev/null; then
    echo "El usuario $username ya existe."
else
    adduser --disabled-password --gecos "" "$username"
    echo "$username:$password" | chpasswd
    usermod -aG sudo "$username"
fi

echo "--- Selección de versión PHP ---"
echo "Versiones disponibles: 8.2, 8.3, 8.4"
read -p "Introduce la versión de PHP (ej. 8.2): " php_ver

# Función para ejecutar instalaciones
cat <<EOF > /tmp/instalar_proceso.sh
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
source "\$NVM_DIR/nvm.sh" 2>/dev/null || {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    source "\$NVM_DIR/nvm.sh"
}

# Instalar Nginx y PHP-FPM
sudo apt update
sudo apt install -y nginx php$php_ver-fpm

# PHP con extensiones extra para OJS
sudo apt install -y php$php_ver-cli php$php_ver-common php$php_ver-mysql php$php_ver-xml php$php_ver-curl php$php_ver-mbstring php$php_ver-zip php$php_ver-intl php$php_ver-bcmath php$php_ver-gd

# Composer y Node
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
nvm install --lts
nvm use --lts

# Configuración de carpeta web
sudo mkdir -p /var/www/$username
sudo chown -R www-data:www-data /var/www/$username
sudo chmod -R 775 /var/www/$username

echo "--- Validación ---"
php -v
nginx -v
EOF

# Ejecutar el proceso
chmod +x /tmp/instalar_proceso.sh
sudo bash /tmp/instalar_proceso.sh

rm /tmp/instalar_proceso.sh
echo "Proceso finalizado. Nginx, PHP-FPM y el entorno están listos."
echo "Carpeta web: /var/www/$username"
echo "Recuerda configurar tu VirtualHost en /etc/nginx/sites-available/"
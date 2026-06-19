#!/bin/bash

# Script de instalación para Ubuntu 24.04
# Instala PHP, Composer y Node.js para un usuario específico

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root."
  exit
fi

# 1. Configuración de usuario
echo "--- Configuración de usuario ---"
read -p "Introduce el nombre del nuevo usuario: " username
read -s -p "Introduce la contraseña para $username: " password
echo ""

if id "$username" &>/dev/null; then
    echo "El usuario $username ya existe."
else
    sudo adduser --disabled-password --gecos "" "$username"
    echo "$username:$password" | chpasswd
    sudo usermod -aG sudo "$username"
fi

# 2. Configuración de carpeta web
echo "--- Preparando directorio /var/www/$username ---"
sudo mkdir -p /var/www/"$username"
sudo chown -R "$username":"$username" /var/www/"$username"
sudo chmod -R 775 /var/www/"$username"

# 3. Selección de versión PHP
echo "--- Selección de versión PHP ---"
read -p "Introduce la versión de PHP a instalar (ej. 8.2): " php_ver

# Crear script temporal para ejecutar como usuario
cat <<EOF > /tmp/instalar_env_user.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sudo apt update && sudo apt upgrade -y

# Instalar PHP y extensiones
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php$php_ver php$php_ver-cli php$php_ver-common php$php_ver-mysql php$php_ver-xml php$php_ver-curl php$php_ver-mbstring php$php_ver-zip php$php_ver-intl php$php_ver-bcmath php$php_ver-gd

# Instalar Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# Instalar Node.js vía NVM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="\$HOME/.nvm"
[ -s "\$NVM_DIR/nvm.sh" ] && \. "\$NVM_DIR/nvm.sh"
nvm install --lts

echo "--- Validación de instalación ---"
php -v
composer --version
node -v
EOF

# 4. Ejecutar el script dentro de la sesión del usuario
chmod +x /tmp/instalar_env_user.sh
sudo -u "$username" bash /tmp/instalar_env_user.sh

rm /tmp/instalar_env_user.sh

echo "--------------------------------------------------------"
echo "Instalación completada para el usuario $username."
echo "La carpeta web está en /var/www/$username"
echo "--------------------------------------------------------"
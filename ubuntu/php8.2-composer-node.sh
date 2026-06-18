#!/bin/bash

# Script de instalación para Ubuntu 24.04
# PHP 8.2, Composer, Node.js y soporte MySQL

# 0. Crear nuevo usuario
echo "--- Configuración de usuario ---"
read -p "Introduce el nombre del nuevo usuario: " username
read -s -p "Introduce la contraseña para $username: " password
echo ""

# Crear el usuario si no existe
if id "$username" &>/dev/null; then
    echo "El usuario $username ya existe."
else
    sudo adduser --disabled-password --gecos "" "$username"
    echo "$username:$password" | sudo chpasswd
    sudo usermod -aG sudo "$username"
    echo "Usuario $username creado y añadido al grupo sudo."
fi

echo "Iniciando la actualización del sistema..."
sudo apt update && sudo apt upgrade -y

# 1. Instalar PHP 8.2 y extensiones necesarias para MySQL
echo "Instalando PHP 8.2..."
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update
sudo apt install -y php8.2 php8.2-cli php8.2-common php8.2-mysql php8.2-xml php8.2-curl php8.2-mbstring php8.2-zip php8.2-intl

# 2. Instalar Composer
echo "Instalando Composer..."
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# 3. Instalar Node.js (usando NVM recomendado)
echo "Instalando Node.js..."
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Exportar variables para usar NVM inmediatamente
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

nvm install --lts
nvm use --lts


echo "--------------------------------------------------------"
echo "Instalación completada con éxito para el usuario: $username"
echo "Verifica las versiones con:"
echo "php -v"
echo "composer --version"
echo "node -v"
echo "--------------------------------------------------------"
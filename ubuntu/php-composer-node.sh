#!/bin/bash

# Verificar que se ejecute como root
if [ "$EUID" -ne 0 ]; then
  echo "Por favor, ejecuta este script como root (sudo)."
  exit
fi

echo "--- Configuración de Usuario ---"
read -p "Nombre del nuevo usuario: " username
read -s -p "Contraseña para $username: " password
echo ""

# Crear usuario
if id "$username" &>/dev/null; then
    echo "El usuario $username ya existe."
else
    adduser --disabled-password --gecos "" "$username"
    echo "$username:$password" | chpasswd
    usermod -aG sudo "$username"
    echo "Usuario $username creado."
fi

echo "--- Selección de versión PHP ---"
echo "Versiones disponibles: 8.2, 8.3, 8.4"
read -p "Introduce la versión de PHP que deseas instalar (ej. 8.2): " php_ver

# Función para ejecutar instalaciones
cat <<EOF > /tmp/instalar_proceso.sh
#!/bin/bash
export NVM_DIR="\$HOME/.nvm"
source "\$NVM_DIR/nvm.sh" 2>/dev/null || {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    source "\$NVM_DIR/nvm.sh"
}

# PHP
sudo apt install -y php$php_ver php$php_ver-cli php$php_ver-common php$php_ver-mysql php$php_ver-xml php$php_ver-curl php$php_ver-mbstring php$php_ver-zip php$php_ver-intl

# Composer
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer

# Node.js
nvm install --lts
nvm use --lts

# Configuración de carpeta web
echo "--- Creando directorio web en /var/www/$username ---"
sudo mkdir -p /var/www/$username
sudo chown -R $username:$username /var/www/$username
sudo chmod -R 755 /var/www/$username

echo "--- Validación de instalación ---"
php -v
composer --version
node -v
EOF

# Ejecutar el proceso como el usuario creado
chmod +x /tmp/instalar_proceso.sh
sudo -u "$username" bash /tmp/instalar_proceso.sh

rm /tmp/instalar_proceso.sh
echo "Proceso finalizado. El entorno está configurado para $username."
echo "Tu carpeta web está lista en: /var/www/$username"
#!/bin/bash

# ==============================================================================
# SCRIPT DE AUTOINSTALACIÓN PARA ENTORNO DE DESARROLLO/PRODUCCIÓN
# Soporta: PHP (8.2, 8.3, 8.4, 8.5), Composer (sin restricción de root),
#          Node.js, Git, Nginx y PM2.
# ==============================================================================

# Colores para la consola
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

# Función para imprimir mensajes informativos
info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Función para imprimir mensajes de éxito
success() {
    echo -e "${GREEN}[ÉXITO]${NC} $1"
}

# Función para imprimir advertencias
warn() {
    echo -e "${YELLOW}[ADVERTENCIA]${NC} $1"
}

# Función para imprimir errores catastróficos
error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 1. Verificar privilegios de administrador (root)
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ser ejecutado como root o utilizando 'sudo'."
fi

# Detectar distribución (Compatible con Debian/Ubuntu)
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    error "No se pudo determinar el sistema operativo. Este script está diseñado para Ubuntu/Debian."
fi

info "Iniciando instalación del entorno en un sistema de tipo: $OS ($VERSION_CODENAME)..."

# 2. Actualización inicial del sistema
info "Actualizando los repositorios y paquetes del sistema..."
apt-get update && apt-get upgrade -y || error "Fallo al actualizar el sistema."
apt-get install -y software-properties-common curl git zip unzip ca-certificates gnupg build-essential || error "No se pudieron instalar dependencias iniciales."

# 3. Instalación de Nginx y Git
info "Instalando Nginx y Git..."
apt-get install -y nginx git || error "Fallo al instalar Nginx o Git."
systemctl enable nginx
systemctl start nginx
success "Nginx y Git instalados e iniciados correctamente."

# 4. Configurar Repositorio para múltiples versiones de PHP (Ondrej Surý)
if [ "$OS" = "ubuntu" ]; then
    info "Añadiendo el repositorio PPA de Ondrej para PHP..."
    add-apt-repository ppa:ondrej/php -y || error "Fallo al añadir el PPA de PHP."
    apt-get update
elif [ "$OS" = "debian" ]; then
    info "Configurando el repositorio de Ondrej para Debian PHP..."
    curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
    echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $VERSION_CODENAME main" > /etc/apt/sources.list.d/php.list
    apt-get update
else
    error "Distribución no soportada directamente por este script."
fi

# 5. Instalar versiones de PHP (8.2, 8.3, 8.4, 8.5) con extensiones comunes
PHP_VERSIONS=("8.2" "8.3" "8.4" "8.5")

for VERSION in "${PHP_VERSIONS[@]}"; do
    info "Instalando PHP $VERSION y extensiones recomendadas..."
    apt-get install -y \
        php$VERSION \
        php$VERSION-cli \
        php$VERSION-common \
        php$VERSION-fpm \
        php$VERSION-mysql \
        php$VERSION-xml \
        php$VERSION-curl \
        php$VERSION-mbstring \
        php$VERSION-zip \
        php$VERSION-gd \
        php$VERSION-intl \
        php$VERSION-bcmath \
        php$VERSION-opcache || warn "No se pudo instalar completamente PHP $VERSION. Es posible que algunas subversiones (como la 8.5) no estén disponibles todavía en tu versión de SO."
    
    # Asegurar que FPM esté iniciado y habilitado
    if systemctl list-unit-files | grep -q "php$VERSION-fpm"; then
        systemctl enable php$VERSION-fpm
        systemctl start php$VERSION-fpm
        success "PHP $VERSION FPM configurado y activo."
    fi
done

# Establecer PHP 8.4 como predeterminado por consola por seguridad (ajustable)
update-alternatives --set php /usr/bin/php8.4 || warn "No se pudo establecer la versión PHP predeterminada."

# 6. Instalar Composer y omitir restricción/advertencia de root
info "Instalando Composer de manera global..."
curl -sS https://getcomposer.org/installer | php || error "Fallo al descargar el instalador de Composer."
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

# Omitir restricción de root de Composer de manera persistente en bash y zsh
info "Configurando el entorno para quitar advertencia de ejecución de Composer como ROOT..."
echo 'export COMPOSER_ALLOW_SUPERUSER=1' >> /root/.bashrc
if [ -f /root/.zshrc ]; then
    echo 'export COMPOSER_ALLOW_SUPERUSER=1' >> /root/.zshrc
fi
# Aplicar variable para la sesión actual del script
export COMPOSER_ALLOW_SUPERUSER=1

success "Composer instalado correctamente. Variable COMPOSER_ALLOW_SUPERUSER configurada."

# 7. Instalar Node.js de manera global (versión LTS actual - Node 22 o superior)
info "Configurando el repositorio oficial de NodeSource para Node.js LTS..."
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg || error "Error al importar la llave de NodeSource."

# Usaremos Node 22 (LTS activo en 2026)
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
apt-get update
apt-get install -y nodejs || error "Fallo al instalar Node.js."

# Verificar versiones de Node y NPM instaladas
NODE_VER=$(node -v)
NPM_VER=$(npm -v)
success "Node.js instalado: $NODE_VER (NPM: $NPM_VER) como root."

# 8. Instalar PM2 de manera global para gestionar procesos Node.js
info "Instalando PM2 de manera global vía NPM..."
npm install -g pm2 || error "Fallo al instalar PM2 de manera global."
success "PM2 instalado correctamente."

# 9. Resumen de la Instalación
echo -e "\n======================================================================"
echo -e "                   ${GREEN}INSTALACIÓN COMPLETADA CON ÉXITO${NC}"
echo -e "======================================================================"
echo -e "Estado de los servicios e instalaciones realizadas:"
echo -e ""
echo -e "  - ${BLUE}Git:${NC} $(git --version)"
echo -e "  - ${BLUE}Nginx:${NC} $(nginx -v 2>&1)"
echo -e "  - ${BLUE}Composer:${NC} $(composer --version | head -n 1) (Permitido root de manera permanente)"
echo -e "  - ${BLUE}NodeJS:${NC} $(node -v)"
echo -e "  - ${BLUE}NPM:${NC} $(npm -v)"
echo -e "  - ${BLUE}PM2:${NC} v$(pm2 -v)"
echo -e ""
echo -e "Versiones de PHP disponibles:"
for VERSION in "${PHP_VERSIONS[@]}"; do
    if [ -f "/usr/bin/php$VERSION" ]; then
        echo -e "  - ${GREEN}PHP $VERSION:${NC} Activo (/usr/bin/php$VERSION)"
    else
        echo -e "  - ${RED}PHP $VERSION:${NC} No instalado o no disponible temporalmente en el PPA."
    fi
done
echo -e ""
echo -e "Versión PHP predeterminada en consola: $(php -v | head -n 1)"
echo -e "======================================================================"
echo -e "Recuerda ejecutar: ${YELLOW}source ~/.bashrc${NC} en tu terminal para aplicar"
echo -e "los cambios de Composer inmediatamente sin cerrar sesión."
echo -e "======================================================================"
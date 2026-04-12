#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Validar variables de entorno críticas
# ─────────────────────────────────────────────
if [ -z "$MYSQL_DATABASE" ] || [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASSWORD" ]; then
    echo "❌ ERROR: Las variables MYSQL_DATABASE, MYSQL_USER y MYSQL_PASSWORD son obligatorias."
    exit 1
fi

if [ "$1" = "php-fpm" ] && [ -z "$MOODLE_ADMIN_PASS" ]; then
    echo "❌ ERROR: MOODLE_ADMIN_PASS no está definida. No se puede instalar Moodle con contraseña vacía o por defecto."
    exit 1
fi

if [ "$1" = "php-fpm" ] && [ -z "$SERVICE_URL_NGINX" ]; then
    echo "❌ ERROR: SERVICE_URL_NGINX no está definida. Ejemplo: https://moodle.tudominio.com"
    exit 1
fi

# MOODLE_ADMIN_EMAIL es obligatoria para recibir alertas de seguridad
if [ "$1" = "php-fpm" ] && [ -z "$MOODLE_ADMIN_EMAIL" ]; then
    echo "❌ ERROR: MOODLE_ADMIN_EMAIL no está definida. Es necesaria para recibir notificaciones críticas de seguridad de Moodle."
    exit 1
fi

# ─────────────────────────────────────────────
# Esperar a que la base de datos esté lista
# ─────────────────────────────────────────────
echo "⏳ Esperando a que la base de datos esté disponible..."
RETRIES=30
until php -r "
    try {
        new PDO(
            'mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8',
            getenv('MYSQL_USER'),
            getenv('MYSQL_PASSWORD')
        );
        exit(0);
    } catch (Exception \$e) {
        exit(1);
    }
" 2>/dev/null; do
    RETRIES=$((RETRIES - 1))
    if [ "$RETRIES" -le 0 ]; then
        echo "❌ ERROR: No se pudo conectar a la base de datos después de varios intentos. Abortando."
        exit 1
    fi
    echo "   Base de datos no disponible aún. Reintentando en 3 segundos... ($RETRIES intentos restantes)"
    sleep 3
done
echo "✅ ¡Base de datos lista!"

# ─────────────────────────────────────────────
# Dar permisos correctos al directorio de datos
# ─────────────────────────────────────────────
chown -R www-data:www-data /var/www/moodledata
chmod 750 /var/www/moodledata

# ─────────────────────────────────────────────
# Instalación o restauración de Moodle
# ─────────────────────────────────────────────
if [ ! -s "/config_mount/config.php" ] && [ "$1" = "php-fpm" ]; then
    echo "🔧 Generando configuración para Moodle..."

    EXTRA_ARGS=""
    TABLE_COUNT=$(php -r "
        try {
            \$db = new PDO(
                'mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8',
                getenv('MYSQL_USER'),
                getenv('MYSQL_PASSWORD')
            );
            \$stmt = \$db->query('SHOW TABLES');
            echo \$stmt->rowCount();
        } catch (Exception \$e) {
            echo 0;
        }
    ")

    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo "✅ La base de datos ya tiene tablas. Se reutilizará con --skip-database."
        EXTRA_ARGS="--skip-database"
    else
        echo "⚠️  Base de datos vacía. Instalando tablas de Moodle desde cero..."
    fi

    php /var/www/html/admin/cli/install.php \
        --lang=es \
        --wwwroot="$SERVICE_URL_NGINX" \
        --dataroot="/var/www/moodledata" \
        --dbtype="mariadb" \
        --dbhost="db" \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbpass="$MYSQL_PASSWORD" \
        --fullname="Plataforma Moodle" \
        --shortname="Moodle" \
        --adminuser="${MOODLE_ADMIN_USER:-admin}" \
        --adminpass="$MOODLE_ADMIN_PASS" \
        --adminemail="$MOODLE_ADMIN_EMAIL" \
        --non-interactive \
        --agree-license \
        $EXTRA_ARGS

    # Guardar config.php en el volumen persistente con permisos restringidos
    cp /var/www/html/config.php /config_mount/config.php
    chown www-data:www-data /config_mount/config.php
    chmod 640 /config_mount/config.php
    echo "✅ Instalación completada y config.php guardado en volumen persistente."

elif [ -s "/config_mount/config.php" ]; then
    echo "♻️  Moodle ya instalado. Restaurando config.php desde volumen persistente..."
    cp /config_mount/config.php /var/www/html/config.php
    chown www-data:www-data /var/www/html/config.php
    chmod 640 /var/www/html/config.php
fi

# ─────────────────────────────────────────────
# Configuración SSL Proxy para Coolify
# (evita ERR_TOO_MANY_REDIRECTS con proxy inverso)
# ─────────────────────────────────────────────
if [ -f "/var/www/html/config.php" ] && [ "$1" = "php-fpm" ]; then
    if ! grep -q "sslproxy" /var/www/html/config.php; then
        echo "🔒 Añadiendo configuración de SSL Proxy para Coolify..."
        sed -i "/require_once/i \$CFG->sslproxy = true;" /var/www/html/config.php
    fi

    # Sincronizar cambios al volumen persistente con permisos restringidos
    cp /var/www/html/config.php /config_mount/config.php
fi

# ─────────────────────────────────────────────
# Permisos finales sobre config.php
# IMPORTANTE: 640 (no 644) — solo www-data puede leer las credenciales
# ─────────────────────────────────────────────
if [ -f "/var/www/html/config.php" ]; then
    chown www-data:www-data /var/www/html/config.php 2>/dev/null || true
    chmod 640 /var/www/html/config.php 2>/dev/null || true
fi
if [ -f "/config_mount/config.php" ]; then
    chown www-data:www-data /config_mount/config.php 2>/dev/null || true
    chmod 640 /config_mount/config.php 2>/dev/null || true
fi

# ─────────────────────────────────────────────
# Arrancar proceso principal (php-fpm u otro)
# ─────────────────────────────────────────────
echo "🚀 Arrancando: $@"
exec "$@"
#!/bin/bash
set -e

# Esperar a que la base de datos esté lista
echo "Esperando a la base de datos..."
while ! php -r "try { new PDO('mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8', getenv('MYSQL_USER'), getenv('MYSQL_PASSWORD')); echo 'Conexión exitosa'; exit(0); } catch (Exception \$e) { exit(1); }"; do
    sleep 3
done
echo "¡Base de datos lista!"
# Dar permisos correctos al iniciar el contenedor
chown -R www-data:www-data /var/www/moodledata
# Instalar Moodle si el config.php no existe todavía (ahora como archivo real)
if [ ! -s "/config_mount/config.php" ] && [ "$1" = "php-fpm" ]; then
    echo "Generando configuración para Moodle..."

    EXTRA_ARGS=""
    TABLE_COUNT=$(php -r "try { \$db = new PDO('mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8', getenv('MYSQL_USER'), getenv('MYSQL_PASSWORD')); \$stmt = \$db->query('SHOW TABLES'); echo \$stmt->rowCount(); } catch (Exception \$e) { echo 0; }")
    if [ "$TABLE_COUNT" -gt 0 ]; then
        echo "✅ La base de datos ya tiene tablas. Se generará el archivo config.php reutilizando la base de datos existente (--skip-database)."
        EXTRA_ARGS="--skip-database"
    else
        echo "⚠️ Base de datos en blanco. Instalando las tablas de Moodle desde cero..."
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
        --adminpass="${MOODLE_ADMIN_PASS:-password123}" \
        --adminemail="admin@tudominio.com" \
        --non-interactive \
        --agree-license \
        $EXTRA_ARGS

    # Hacer una copia persistente al volumen seguro del host (porque el HTML es volátil entre builds)
    cp /var/www/html/config.php /config_mount/config.php
    
    # Asegurar permisos del config.php para que Nginx/PHP-FPM pueda leerlo
    chown www-data:www-data /config_mount/config.php
    chmod 644 /config_mount/config.php
    echo "Instalación completada y copia guardada."
elif [ -s "/config_mount/config.php" ]; then
    echo "Moodle ya está instalado. Restaurando config.php desde persistencia..."
    cp /config_mount/config.php /var/www/html/config.php
    chown www-data:www-data /var/www/html/config.php
    chmod 644 /var/www/html/config.php
fi

# Solucionar problema de ERR_TOO_MANY_REDIRECTS por el proxy inverso de Coolify
if [ -f "/var/www/html/config.php" ] && [ "$1" = "php-fpm" ]; then
    if ! grep -q "sslproxy" /var/www/html/config.php; then
        echo "Añadiendo configuración de SSL Proxy a config.php..."
        sed -i "/require_once/i \$CFG->sslproxy = true;\n" /var/www/html/config.php
    fi
    # Eliminar reverseproxy si causa bloqueo ("Proxy inverso habilitado...")
    sed -i "/\$CFG->reverseproxy = true;/d" /var/www/html/config.php
    # Volver a guardar el cambio en el volumen persistente
    cp /var/www/html/config.php /config_mount/config.php
fi

# Arrancar el proceso principal de PHP-FPM o el comando original (ej: cron)
exec "$@"

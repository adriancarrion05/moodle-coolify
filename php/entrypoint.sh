#!/bin/bash
set -e

# Esperar a que la base de datos esté lista
echo "Esperando a la base de datos..."
while ! php -r "try { new PDO('mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8', getenv('MYSQL_USER'), getenv('MYSQL_PASSWORD')); echo 'Conexión exitosa'; exit(0); } catch (Exception \$e) { exit(1); }"; do
    sleep 3
done
echo "¡Base de datos lista!"

# Instalar Moodle si el config.php no existe todavía (ahora como archivo real)
if [ ! -s "/config_mount/config.php" ]; then
    echo "Instalando Moodle (esto solo sucederá la primera vez)..."

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
        --adminuser="admin" \
        --adminpass="ContraseñaAdminFuerte1!" \
        --adminemail="admin@tudominio.com" \
        --non-interactive \
        --agree-license
    
    # Hacer una copia persistente al volumen seguro del host (porque el HTML es volátil entre builds)
    cp /var/www/html/config.php /config_mount/config.php
    
    # Asegurar permisos del config.php para que Nginx/PHP-FPM pueda leerlo
    chown www-data:www-data /config_mount/config.php
    chmod 644 /config_mount/config.php
    echo "Instalación completada y copia guardada."
else
    echo "Moodle ya está instalado. Restaurando config.php desde persistencia..."
    cp /config_mount/config.php /var/www/html/config.php
    chown www-data:www-data /var/www/html/config.php
    chmod 644 /var/www/html/config.php
fi

# Arrancar el proceso principal de PHP-FPM o el comando original (ej: cron)
exec "$@"

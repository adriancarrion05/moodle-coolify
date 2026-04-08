#!/bin/bash
set -e

# Esperar a que la base de datos esté lista
echo "Esperando a la base de datos..."
while ! php -r "try { new PDO('mysql:host=db;dbname=' . getenv('MYSQL_DATABASE') . ';charset=utf8', getenv('MYSQL_USER'), getenv('MYSQL_PASSWORD')); echo 'Conexión exitosa'; exit(0); } catch (Exception \$e) { exit(1); }"; do
    sleep 3
done
echo "¡Base de datos lista!"

# Docker crea los volúmenes de montaje directo como directorios si el archivo no existía en el host
# Revisamos si config.php es un directorio y lo eliminamos para permitir que Moodle lo cree como archivo
if [ -d "/var/www/html/config.php" ]; then
    echo "Corrigiendo montaje de Docker (eliminando directorio config.php)..."
    rm -rf /var/www/html/config.php
fi

# Instalar Moodle si el config.php no existe todavía (ahora como archivo real)
if [ ! -s "/var/www/html/config.php" ]; then
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
        
    # Asegurar permisos del config.php para que Nginx/PHP-FPM pueda leerlo
    chown www-data:www-data /var/www/html/config.php
    chmod 644 /var/www/html/config.php
    echo "Instalación completada y permisos asignados."
else
    echo "Moodle ya está instalado (config.php encontrado)."
fi

# Arrancar el proceso principal de PHP-FPM o el comando original (ej: cron)
exec "$@"

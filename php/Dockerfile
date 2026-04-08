FROM php:8.3-fpm

# Instalar dependencias esenciales y de seguridad
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip libpng-dev libicu-dev libxml2-dev cron wget \
    libcurl4-openssl-dev libsodium-dev libonig-dev \
    && docker-php-ext-install mysqli pdo_mysql zip gd intl soap opcache exif sodium mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Descargar Moodle directamente dentro de la imagen (Versión 5.0)
RUN wget https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.tgz -O moodle.tgz && \
    tar -zxvf moodle.tgz --strip-components=1 -C /var/www/html && \
    rm moodle.tgz || (echo "Moodle download failed." && exit 1)

# Configurar permisos seguros (evitar escritura global)
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

# Establecer la ejecución mediante nuestro script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
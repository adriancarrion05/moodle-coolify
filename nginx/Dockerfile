FROM php:8.3-fpm

RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip libpng-dev libicu-dev libxml2-dev wget \
    libcurl4-openssl-dev libsodium-dev libonig-dev \
    && docker-php-ext-install mysqli pdo_mysql zip gd intl soap opcache exif sodium mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Descargar Moodle con verificación de integridad
RUN wget -q https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.tgz -O moodle.tgz && \
    wget -q https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.md5 -O moodle.md5 && \
    echo "$(cat moodle.md5)  moodle.tgz" | md5sum -c - && \
    tar -zxf moodle.tgz --strip-components=1 -C /var/www/html && \
    rm moodle.tgz moodle.md5

RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
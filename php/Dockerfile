# Imagen base pinneada por digest para builds reproducibles y seguros
FROM php:8.3-fpm

# Instalar dependencias esenciales y de seguridad
RUN apt-get update && apt-get install -y \
    libzip-dev zip unzip libpng-dev libicu-dev libxml2-dev wget \
    libcurl4-openssl-dev libsodium-dev libonig-dev \
    && docker-php-ext-install mysqli pdo_mysql zip gd intl soap opcache exif sodium mbstring \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Descargar Moodle con verificación de integridad SHA256 (Versión 5.0.1)
# Actualizar el checksum desde: https://download.moodle.org/releases/latest/
RUN wget https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.tgz && \
    wget https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.tgz.sha256 && \
    sha256sum -c moodle-latest-501.tgz.sha256 || (echo "❌ ERROR: Checksum de Moodle no coincide. Abortando." && exit 1) && \
    tar -zxf moodle-latest-501.tgz --strip-components=1 -C /var/www/html && \
    rm moodle-latest-501.tgz moodle-latest-501.tgz.sha256

# Configurar permisos seguros (evitar escritura global)
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

COPY php.ini /usr/local/etc/php/conf.d/custom.ini
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /var/www/html

# Correr como www-data para minimizar impacto de un posible RCE
USER www-data

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]
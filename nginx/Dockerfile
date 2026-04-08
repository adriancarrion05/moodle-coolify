FROM nginx:alpine

# Descargar la MISMA versión de Moodle para Nginx (solo para servir estáticos)
# Esto garantiza que al actualizar, el Nginx tenga la versión correcta sin depender de volúmenes compartidos
RUN apk add --no-cache curl tar \
    && curl -L https://download.moodle.org/download.php/direct/stable501/moodle-latest-501.tgz -o moodle.tgz \
    && mkdir -p /var/www/html \
    && tar -zxvf moodle.tgz --strip-components=1 -C /var/www/html \
    && rm moodle.tgz

# Permisos restrictivos para Nginx (solo lectura)
RUN chown -R nginx:nginx /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \;

COPY moodle.conf /etc/nginx/conf.d/default.conf

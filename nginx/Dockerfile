FROM nginx:1.25-alpine

# Eliminar config por defecto
RUN rm /etc/nginx/conf.d/default.conf

# Copiar configuración de Moodle en build time (evita problema de Coolify con bind mounts)
COPY moodle.conf /etc/nginx/conf.d/moodle.conf

EXPOSE 80
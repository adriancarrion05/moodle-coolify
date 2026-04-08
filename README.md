# Moodle en Coolify (Docker Setup)

Esta configuración está optimizada y securizada para desplegar Moodle (v5.0+) en un entorno de contenedores usando [Coolify](https://coolify.io), resolviendo problemas comunes de arquitectura, permisos y conectividad de proxy inverso.

## 🏗️ Arquitectura
- **Nginx & PHP Desacoplados:** Cada contenedor construye su propia copia del código de Moodle. Se eliminó el uso de un volumen compartido para el código, lo que garantiza actualizaciones limpias y sin problemas de sincronización de caché entre versiones.
- **Base de Datos Robusta:** Se utiliza MariaDB 10.11 con un `healthcheck` para retrasar el inicio de PHP hasta que la base de datos esté lista para aceptar conexiones.
- **Cron Confiable:** Un contenedor independiente ejecuta el mantenimiento de Moodle (`cron.php`) cada 60 segundos en bucle directo de PHP, sin depender del servicio cron del sistema operativo.
- **Persistencia Aislada:** Sólo el directorio de archivos subidos y caché compartida (`moodledata`) persiste en volúmenes de Docker.

## 🔒 Seguridad
- **Nginx Securizado:** Bloqueo estricto a archivos ocultos (`.git`, `.env`), lecturas de logs, archivos de configuración (como `config.php`) y prevención de ejecución web del directorio de comandos CLI (`/admin/cli`).
- **Permisos de Archivos:** Permisos correctos garantizados desde la construcción de las imágenes de Docker (`755` para directorios y `644` para archivos).
- **Extensiones de Producción:** PHP está preparado con los módulos requeridos de seguridad (Sodium, cURL, OPcache, MBString).

## 🚀 Despliegue e Instalación
1. Despliega los servicios en Coolify usando la opción *Docker Compose*.
2. Asegúrate de que las variables de entorno de base de datos (`MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, `MYSQL_ROOT_PASSWORD`) están definidas en el panel de recursos de Coolify.
3. Ingresa a la URL asignada para realizar en el navegador el proceso normal de instalación web de Moodle.

## ⚠️ Puesto en Producción: Arreglar SSL (Proxy Inverso)
Dado que Coolify actúa como Proxy Inverso manejando el protocolo TLS/HTTPS (mediante Traefik/Caddy) y enviando las peticiones a Nginx internamente por HTTP80, Moodle podría presentar errores de redirección infinita o contenido bloqueado por "Mixed Content".

Para solucionar esto, **una vez que finalice la instalación web** y Moodle genere el archivo `config.php`, edítalo y asegúrate de agregar/modificar las siguientes banderas de proxy:

```php
// Definir explícitamente el uso de HTTPS en la URL
$CFG->wwwroot = 'https://tudominio.com';

// Activar la compatibilidad con el Proxy Inverso SSL
$CFG->sslproxy = true;
$CFG->reverseproxy = true; 
```
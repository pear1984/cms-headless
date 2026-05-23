# Portabilidad

Este proyecto se puede mover de dos maneras complementarias:

1. GitHub para el codigo.
2. Bundle Docker para llevar WordPress, MariaDB, uploads, plugins e imagenes.

## Opcion recomendada

Usar ambas:

- GitHub mantiene el historial del frontend Django, templates, CSS, scripts y compose files.
- El bundle Docker mantiene el estado privado de WordPress: base MariaDB y archivos en `wp-content`.

## Crear un bundle portable

Con los contenedores funcionando, ejecutar desde la raiz:

```bash
chmod +x scripts/export_portable_bundle.sh scripts/restore_portable_bundle.sh
./scripts/export_portable_bundle.sh
```

El resultado queda en:

```text
portable_exports/cms-headless-YYYYMMDD-HHMMSS/
```

Ese directorio contiene:

- `code/cms-headless-code.tar.gz`: snapshot limpio del codigo.
- `docker/images.tar`: imagenes necesarias para iniciar sin reconstruir todo desde internet.
- `volumes/wordpress_db_data.tar.gz`: base MariaDB de WordPress.
- `volumes/wordpress_wordpress_data.tar.gz`: archivos WordPress, uploads, plugins y temas.
- `SHA256SUMS.txt`: hashes para verificar integridad.
- `restore_bundle.sh`: restaurador para otra Mac.

## Restaurar en otra Mac

1. Instalar Docker Desktop.
2. Copiar el directorio `cms-headless-YYYYMMDD-HHMMSS`.
3. Ejecutar:

```bash
cd cms-headless-YYYYMMDD-HHMMSS
./restore_bundle.sh
```

Por defecto restaura el codigo en:

```text
~/cms-headless
```

Para elegir otro destino:

```bash
TARGET_DIR="$HOME/Documents/cmd headless" ./restore_bundle.sh
```

## URLs locales

- Django frontend: `http://127.0.0.1:8001/`
- WordPress: `http://127.0.0.1:8080/`
- WordPress admin: `http://127.0.0.1:8080/wp-admin/`
- phpMyAdmin: `http://127.0.0.1:8081/`

## Publicar codigo en GitHub

El repositorio remoto actual es:

```text
https://github.com/pear1984/cms-headless.git
```

Antes de publicar, confirmar que no haya secretos:

```bash
git status --short
git diff --cached --name-only
```

Los `.env`, bundles, `staticfiles`, `.venv` y duplicados de transferencia quedan ignorados por Git.

## Volumenes estables

El stack de WordPress usa nombres de volumen fijos para que el restore no dependa del nombre de la carpeta:

- `wordpress_db_data`
- `wordpress_wordpress_data`

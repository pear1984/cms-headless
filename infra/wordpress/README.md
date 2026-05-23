# WordPress Headless

Stack separado para WordPress con PHP 8.3, MariaDB, WP-CLI, `nginx` y phpMyAdmin. Django no instala ni administra WordPress; solo consume `http://localhost:8080/wp-json/wp/v2/`.

## Uso

Desde esta carpeta:

```bash
docker compose up -d
```

WordPress queda disponible en:

```bash
http://localhost:8080
http://localhost:8080/wp-admin

La URL publica sale por `nginx`; el contenedor `wordpress` queda detras como backend interno.
```

phpMyAdmin queda disponible en:

```bash
http://localhost:8081
```

Las credenciales estan en `.env`:

```bash
WORDPRESS_ADMIN_USER=admin
WORDPRESS_ADMIN_PASSWORD=...
```

Para phpMyAdmin puedes entrar con:

```bash
Servidor: db
Usuario: root
Password: MARIADB_ROOT_PASSWORD
```

Para ver si WP-CLI completo la instalacion:

```bash
docker compose logs wpcli
```

Para detener WordPress:

```bash
docker compose down
```

Para borrar WordPress, base de datos y uploads persistidos:

```bash
docker compose down -v
```

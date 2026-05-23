# Django + WordPress Headless

Proyecto Django que usa WordPress como CMS headless mediante la REST API publica de WordPress.

## Configuracion

1. Crea un entorno virtual e instala dependencias:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

2. Crea tu archivo `.env`:

```bash
cp .env.example .env
```

3. Edita `.env` y completa la URL del WordPress que quieras consumir:

```bash
WORDPRESS_BASE_URL=http://127.0.0.1:8080
```

4. Ejecuta Django:

```bash
python manage.py runserver
```

Abre `http://127.0.0.1:8000`.

## WordPress Separado

WordPress y sus dependencias viven fuera de la logica Python, en:

```bash
infra/wordpress
```

Ese stack contiene:

- WordPress con PHP 8.3.
- MariaDB.
- WP-CLI para instalar WordPress automaticamente.
- phpMyAdmin.
- Volumenes persistentes para base de datos y archivos de WordPress.

Para levantar solo WordPress:

```bash
cd infra/wordpress
docker compose up -d
```

WordPress queda disponible en `http://localhost:8080`, el admin en `http://localhost:8080/wp-admin` y phpMyAdmin en `http://localhost:8081`.

## Django En Docker

Tambien puedes correr el proyecto en contenedor con `nginx` delante de Django y `gunicorn` detras.

1. Crea tu archivo `.env`:

```bash
cp .env.example .env
```

2. Configura la URL de WordPress si usas uno externo:

```bash
WORDPRESS_BASE_URL=https://tusitio.com
```

Si vas a usar el WordPress separado de `infra/wordpress`, puedes dejar `WORDPRESS_BASE_URL` vacio. El contenedor de Django usara por defecto:

```bash
http://host.docker.internal:8080
```

3. Desde la raiz del proyecto, construye y levanta Django:

```bash
docker compose up --build
```

Abre `http://127.0.0.1:8001`.

Puedes cambiar el puerto editando `DJANGO_HTTP_PORT` en `.env`.

Para detenerlo:

```bash
docker compose down
```

## Rutas

- `/`: home con ultimos posts.
- `/blog/<slug>/`: detalle de post.
- `/pagina/<slug>/`: detalle de pagina.
- `/buscar/?q=texto`: busqueda de posts.

## Notas

- WordPress debe tener habilitada la REST API, disponible por defecto en instalaciones modernas.
- Las imagenes destacadas se cargan usando `_embed=wp:featuredmedia`.
- Los menus nativos de WordPress no estan en la REST API core. La navegacion usa paginas padre publicadas.

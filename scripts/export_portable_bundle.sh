#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${1:-"$ROOT_DIR/portable_exports/cms-headless-$STAMP"}"
VOLUME_IMAGE="${VOLUME_IMAGE:-mariadb:11.4}"
WORDPRESS_COMPOSE="$ROOT_DIR/infra/wordpress/docker-compose.yml"
WORDPRESS_WAS_RUNNING=0

mkdir -p "$OUT_DIR"/{code,config,database,docker,volumes}
chmod 700 "$OUT_DIR" "$OUT_DIR/config" "$OUT_DIR/database"

restart_wordpress() {
  if [ "$WORDPRESS_WAS_RUNNING" -eq 1 ]; then
    echo "Restarting WordPress..."
    docker compose -f "$WORDPRESS_COMPOSE" up -d
  fi
}

trap restart_wordpress EXIT

echo "Exporting code snapshot..."
tar -C "$ROOT_DIR" \
  --exclude='./.git' \
  --exclude='./.venv' \
  --exclude='./staticfiles' \
  --exclude='./portable_exports' \
  --exclude='./.env*' \
  --exclude='./infra/wordpress/.env*' \
  --exclude='* 2' \
  --exclude='* 3' \
  --exclude='* 2.*' \
  --exclude='* 3.*' \
  -czf "$OUT_DIR/code/cms-headless-code.tar.gz" .

echo "Exporting private configuration..."
if [ -f "$ROOT_DIR/.env" ]; then
  cp "$ROOT_DIR/.env" "$OUT_DIR/config/django.env"
fi
if [ -f "$ROOT_DIR/infra/wordpress/.env" ]; then
  cp "$ROOT_DIR/infra/wordpress/.env" "$OUT_DIR/config/wordpress.env"
fi
chmod 600 "$OUT_DIR"/config/* 2>/dev/null || true

echo "Exporting MariaDB as portable SQL..."
docker compose -f "$WORDPRESS_COMPOSE" exec -T db \
  sh -c 'mariadb-dump --single-transaction --routines --triggers -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
  | gzip -9 > "$OUT_DIR/database/wordpress.sql.gz"
gzip -t "$OUT_DIR/database/wordpress.sql.gz"
chmod 600 "$OUT_DIR/database/wordpress.sql.gz"

echo "Exporting Docker images..."
docker compose -f "$ROOT_DIR/docker-compose.yml" build
docker save \
  cms-headless-web:latest \
  nginx:1.27-alpine \
  mariadb:11.4 \
  wordpress:php8.3-apache \
  wordpress:cli-php8.3 \
  phpmyadmin:latest \
  "$VOLUME_IMAGE" \
  -o "$OUT_DIR/docker/images.tar"

if docker compose -f "$WORDPRESS_COMPOSE" ps --status running --services | grep -q '^db$'; then
  WORDPRESS_WAS_RUNNING=1
  echo "Stopping WordPress briefly for a consistent physical volume snapshot..."
  docker compose -f "$WORDPRESS_COMPOSE" stop
fi

export_volume() {
  local volume_name="$1"
  local output_name="$2"

  echo "Exporting volume $volume_name..."
  docker volume inspect "$volume_name" >/dev/null
  docker run --rm \
    --entrypoint sh \
    -v "$volume_name:/volume:ro" \
    -v "$OUT_DIR/volumes:/backup" \
    "$VOLUME_IMAGE" \
    -c "cd /volume && tar -czf /backup/$output_name ."
}

export_volume wordpress_db_data wordpress_db_data.tar.gz
export_volume wordpress_wordpress_data wordpress_wordpress_data.tar.gz

restart_wordpress
WORDPRESS_WAS_RUNNING=0

cat > "$OUT_DIR/RESTORE.md" <<'EOF'
# Restore

1. Install Docker Desktop.
2. Copy this whole folder to the new machine.
3. From inside this folder, run:

```bash
./restore_bundle.sh
```

The app will be available at:

- Django frontend: http://127.0.0.1:8001/
- WordPress: http://127.0.0.1:8080/
- WordPress admin: http://127.0.0.1:8080/wp-admin/
- phpMyAdmin: http://127.0.0.1:8081/

This private bundle includes:

- Django and WordPress configuration files.
- A portable MariaDB SQL dump.
- A physical MariaDB volume snapshot.
- WordPress core, plugins, themes, and uploads.
- All required Docker images.
EOF

cp "$ROOT_DIR/scripts/restore_portable_bundle.sh" "$OUT_DIR/restore_bundle.sh"
chmod +x "$OUT_DIR/restore_bundle.sh"

(
  cd "$OUT_DIR"
  shasum -a 256 \
    code/cms-headless-code.tar.gz \
    config/* \
    database/wordpress.sql.gz \
    docker/images.tar \
    volumes/*.tar.gz > SHA256SUMS.txt
)

echo "Portable bundle created at:"
echo "$OUT_DIR"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${1:-"$ROOT_DIR/portable_exports/cms-headless-$STAMP"}"
VOLUME_IMAGE="${VOLUME_IMAGE:-mariadb:11.4}"

mkdir -p "$OUT_DIR"/{code,docker,volumes}

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
EOF

cp "$ROOT_DIR/scripts/restore_portable_bundle.sh" "$OUT_DIR/restore_bundle.sh"
chmod +x "$OUT_DIR/restore_bundle.sh"

(
  cd "$OUT_DIR"
  shasum -a 256 code/cms-headless-code.tar.gz docker/images.tar volumes/*.tar.gz > SHA256SUMS.txt
)

echo "Portable bundle created at:"
echo "$OUT_DIR"

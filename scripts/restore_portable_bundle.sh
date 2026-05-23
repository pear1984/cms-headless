#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${TARGET_DIR:-"$HOME/cms-headless"}"
VOLUME_IMAGE="${VOLUME_IMAGE:-mariadb:11.4}"

require_file() {
  if [ ! -f "$1" ]; then
    echo "Missing required file: $1" >&2
    exit 1
  fi
}

require_file "$BUNDLE_DIR/code/cms-headless-code.tar.gz"
require_file "$BUNDLE_DIR/docker/images.tar"
require_file "$BUNDLE_DIR/volumes/wordpress_db_data.tar.gz"
require_file "$BUNDLE_DIR/volumes/wordpress_wordpress_data.tar.gz"

if [ -f "$BUNDLE_DIR/SHA256SUMS.txt" ]; then
  echo "Checking bundle hashes..."
  (cd "$BUNDLE_DIR" && shasum -a 256 -c SHA256SUMS.txt)
fi

echo "Loading Docker images..."
docker load -i "$BUNDLE_DIR/docker/images.tar"

echo "Restoring code to $TARGET_DIR..."
mkdir -p "$TARGET_DIR"
tar -C "$TARGET_DIR" -xzf "$BUNDLE_DIR/code/cms-headless-code.tar.gz"

restore_volume() {
  local volume_name="$1"
  local archive_path="$2"

  echo "Restoring volume $volume_name..."
  docker volume create "$volume_name" >/dev/null
  docker run --rm \
    --entrypoint sh \
    -v "$volume_name:/volume" \
    -v "$(dirname "$archive_path"):/backup:ro" \
    "$VOLUME_IMAGE" \
    -c "cd /volume && tar -xzf /backup/$(basename "$archive_path")"
}

restore_volume wordpress_db_data "$BUNDLE_DIR/volumes/wordpress_db_data.tar.gz"
restore_volume wordpress_wordpress_data "$BUNDLE_DIR/volumes/wordpress_wordpress_data.tar.gz"

if [ ! -f "$TARGET_DIR/.env" ]; then
  cp "$TARGET_DIR/.env.example" "$TARGET_DIR/.env"
fi

if [ ! -f "$TARGET_DIR/infra/wordpress/.env" ]; then
  cp "$TARGET_DIR/infra/wordpress/.env.example" "$TARGET_DIR/infra/wordpress/.env"
fi

echo "Starting WordPress..."
docker compose -f "$TARGET_DIR/infra/wordpress/docker-compose.yml" up -d

echo "Starting Django frontend..."
docker compose -f "$TARGET_DIR/docker-compose.yml" up -d --build

echo "Restore finished."
echo "Django frontend: http://127.0.0.1:8001/"
echo "WordPress: http://127.0.0.1:8080/"
echo "WordPress admin: http://127.0.0.1:8080/wp-admin/"
echo "phpMyAdmin: http://127.0.0.1:8081/"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

RAW_JSON_DIR="data/raw/motogp"
ARCHIVE_DIR="$RAW_JSON_DIR/archive"
ARCHIVE_FILE="$ARCHIVE_DIR/motogp_raw_json_$(date +%Y%m%d_%H%M%S).tar.gz"
DOCKER=(docker)

if command -v sudo >/dev/null 2>&1; then
  sudo -v
  DOCKER=(sudo docker)
fi

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    echo "Creado .env desde .env.example"
  else
    echo "No existe .env ni .env.example. Crea .env antes de continuar." >&2
    exit 1
  fi
fi

EXISTING_CONTAINERS="$("${DOCKER[@]}" compose ps -aq)"
if [[ -n "$EXISTING_CONTAINERS" ]]; then
  echo "Destruyendo contenedores existentes..."
  if ! "${DOCKER[@]}" compose down --remove-orphans; then
    echo "docker compose down fallo. Forzando eliminacion de contenedores..."
    REMAINING_CONTAINERS="$("${DOCKER[@]}" compose ps -aq)"
    if [[ -n "$REMAINING_CONTAINERS" ]]; then
      "${DOCKER[@]}" rm -f $REMAINING_CONTAINERS
    fi
  fi
fi

echo "Levantando contenedores..."
"${DOCKER[@]}" compose up -d --build

echo "Esperando a PostgreSQL..."
until "${DOCKER[@]}" compose exec -T postgres pg_isready -U motogp_user -d motogp >/dev/null 2>&1; do
  sleep 2
done

echo "Ejecutando ingesta MotoGP..."
"${DOCKER[@]}" compose exec -T app python src/extract_motogp.py "$@"

if [[ -d "$RAW_JSON_DIR" ]] && find "$RAW_JSON_DIR" -type f -name '*.json' -print -quit | grep -q .; then
  echo "Archivando JSON crudos en $ARCHIVE_FILE..."
  mkdir -p "$ARCHIVE_DIR"
  find "$RAW_JSON_DIR" -type f -name '*.json' ! -path "$ARCHIVE_DIR/*" -print0 \
    | tar --null --files-from - --create --gzip --file "$ARCHIVE_FILE" --remove-files
else
  echo "No hay JSON crudos para archivar en $RAW_JSON_DIR."
fi

echo "Ejecutando dbt run..."
"${DOCKER[@]}" compose exec -T app dbt run --profiles-dir .

echo "Carga completa finalizada."

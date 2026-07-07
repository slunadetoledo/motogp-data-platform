#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

RAW_JSON_DIR="data/raw/motogp"
ARCHIVE_DIR="$RAW_JSON_DIR/archive"
ARCHIVE_FILE="$ARCHIVE_DIR/motogp_raw_json_$(date +%Y%m%d_%H%M%S).tar.gz"
DOCKER=(docker)
COMPOSE=()

if ! docker info >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
  sudo -v
  DOCKER=(sudo docker)
fi

if "${DOCKER[@]}" compose version >/dev/null 2>&1; then
  COMPOSE=("${DOCKER[@]}" compose)
elif command -v docker-compose >/dev/null 2>&1; then
  if [[ "${DOCKER[0]}" == "sudo" ]]; then
    COMPOSE=(sudo docker-compose)
  else
    COMPOSE=(docker-compose)
  fi
else
  echo "No se encontro Docker Compose. Instala el plugin 'docker compose' o el binario 'docker-compose'." >&2
  exit 1
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

EXISTING_CONTAINERS="$("${COMPOSE[@]}" ps --all --quiet)"
if [[ -n "$EXISTING_CONTAINERS" ]]; then
  echo "Destruyendo contenedores existentes..."
  if ! "${COMPOSE[@]}" down --remove-orphans; then
    echo "docker compose down fallo. Forzando eliminacion de contenedores..."
    REMAINING_CONTAINERS="$("${COMPOSE[@]}" ps --all --quiet)"
    if [[ -n "$REMAINING_CONTAINERS" ]]; then
      "${DOCKER[@]}" rm -f $REMAINING_CONTAINERS
    fi
  fi
fi

echo "Levantando contenedores..."
"${COMPOSE[@]}" up -d --build

echo "Esperando a PostgreSQL..."
MAX_WAIT=30
ELAPSED=0
until "${COMPOSE[@]}" exec -T postgres pg_isready -U motogp_user -d motogp >/dev/null 2>&1; do
  if (( ELAPSED >= MAX_WAIT )); then
    echo "PostgreSQL no estuvo listo en $MAX_WAIT segundos. Abortando." >&2
    exit 1
  fi
  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

echo "Ejecutando ingesta MotoGP..."
"${COMPOSE[@]}" exec -T app python src/extract_motogp.py "$@"

if [[ -d "$RAW_JSON_DIR" ]] && find "$RAW_JSON_DIR" -type f -name '*.json' -print -quit | grep -q .; then
  echo "Archivando JSON crudos en $ARCHIVE_FILE..."
  mkdir -p "$ARCHIVE_DIR"
  find "$RAW_JSON_DIR" -type f -name '*.json' ! -path "$ARCHIVE_DIR/*" -print0 \
    | tar --null --files-from - --create --gzip --file "$ARCHIVE_FILE" --remove-files
else
  echo "No hay JSON crudos para archivar en $RAW_JSON_DIR."
fi

echo "Ejecutando dbt run..."
"${COMPOSE[@]}" exec -T app dbt run --profiles-dir .

echo "Carga completa finalizada."

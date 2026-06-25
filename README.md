# motogp-data-platform

## Levantar el entorno

Si no existe el fichero `.env`, crealo desde el ejemplo:

```bash
cp .env.example .env
```

Levanta PostgreSQL y el contenedor de la aplicacion:

```bash
docker compose up -d --build
```

Si cambias el `Dockerfile` o las dependencias, vuelve a ejecutar el comando
anterior para reconstruir la imagen.

La primera vez que se crea el volumen de PostgreSQL, Docker ejecuta los SQL de
`sql/init` y crea los esquemas `raw`, `bronze`, `silver` y `gold`, junto con las
tablas base.

Si el volumen ya existia y faltan esquemas o tablas, inicializalos manualmente:

```bash
docker compose exec postgres psql -U motogp_user -d motogp \
  -f /docker-entrypoint-initdb.d/01_create_schemas.sql \
  -f /docker-entrypoint-initdb.d/02_create_raw_tables.sql
```

## Carga completa 2024

El extractor carga la temporada `2024` por defecto cuando no se indica ningun
parametro.

```bash
# Comprueba que dbt puede conectar con PostgreSQL
docker compose exec app dbt debug --profiles-dir .

# Carga datos de MotoGP 2024 en raw/bronze
docker compose exec app python src/extract_motogp.py

# Construye los modelos silver/gold
docker compose exec app dbt run --profiles-dir .

# Ejecuta los tests de dbt
docker compose exec app dbt test --profiles-dir .
```

Equivalente explicito para 2024:

```bash
docker compose exec app python src/extract_motogp.py 2024
```

Tambien puedes lanzar la transformacion y los tests de dbt en un solo paso:

```bash
docker compose exec app dbt build --profiles-dir .
```

## Cambiar temporada

Cargar una temporada concreta:

```bash
docker compose exec app python src/extract_motogp.py 2025
```

Cargar todas las temporadas devueltas por la API:

```bash
docker compose exec app python src/extract_motogp.py all
```

Despues de cualquier carga, vuelve a ejecutar dbt:

```bash
docker compose exec app dbt run --profiles-dir .
docker compose exec app dbt test --profiles-dir .
```

## Cargas parciales

Puedes cargar solo un recurso con `--only`. Si no indicas temporada, se usa
`2024`.

```bash
# Pilotos y estadisticas de pilotos
docker compose exec app python src/extract_motogp.py --only riders

# Categorias 2024
docker compose exec app python src/extract_motogp.py 2024 --only result_categories

# Eventos 2024
docker compose exec app python src/extract_motogp.py 2024 --only result_events

# Sesiones 2024
docker compose exec app python src/extract_motogp.py 2024 --only result_sessions

# Parrillas 2024
docker compose exec app python src/extract_motogp.py 2024 --only result_grid

# Clasificaciones de sesiones 2024
docker compose exec app python src/extract_motogp.py 2024 --only result_classification
```

`--only` acepta varios recursos separados por comas:

```bash
docker compose exec app python src/extract_motogp.py 2024 \
  --only result_categories,result_events,result_sessions,result_grid,result_classification
```

Recursos disponibles:

```text
riders
result_categories
result_events
result_standings
result_sessions
result_grid
result_classification
```

Para `result_grid` y `result_classification`, el extractor carga las dependencias
necesarias para llegar a esos endpoints, como eventos, categorias y sesiones.

## Comandos utiles

Ver logs de los contenedores:

```bash
docker compose logs -f
```

Abrir una consola SQL en PostgreSQL:

```bash
docker compose exec postgres psql -U motogp_user -d motogp
```

Parar los contenedores:

```bash
docker compose down
```

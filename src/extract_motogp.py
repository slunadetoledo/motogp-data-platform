from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import os

import requests
from sqlalchemy import create_engine, text


BASE_URL = "https://api.pulselive.motogp.com/motogp/v1"
RAW_PATH = Path("data/raw/motogp")
DEFAULT_YEAR = 2024  # Sin parametros, el extractor carga la temporada 2024.
DEFAULT_RESOURCES = (
    "riders",
    "result_categories",
    "result_events",
    "result_standings",
    "result_sessions",
    "result_grid",
    "result_classification",
)
RESOURCE_ALIASES = {
    "riders": "riders",
    "result_categories": "result_categories",
    "result_category": "result_categories",
    "categories": "result_categories",
    "result_events": "result_events",
    "result_event": "result_events",
    "events": "result_events",
    "result_standings": "result_standings",
    "result_standing": "result_standings",
    "standings": "result_standings",
    "result_sessions": "result_sessions",
    "result_session": "result_sessions",
    "sessions": "result_sessions",
    "result_grid": "result_grid",
    "result_frid": "result_grid",
    "grid": "result_grid",
    "result_classification": "result_classification",
    "classification": "result_classification",
}

BRONZE_LOAD_SQL = {
    "results/seasons": """
        INSERT INTO bronze.motogp_seasons (
            raw_id,
            season_id,
            season_year,
            extraction_date
        )
        SELECT
            r.id,
            season ->> 'id',
            NULLIF(season ->> 'year', '')::INTEGER,
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                ELSE jsonb_build_array(r.payload)
            END
        ) season
        WHERE r.id = :raw_id
    """,
    "results/categories": """
        INSERT INTO bronze.motogp_categories (
            raw_id,
            category_id,
            category_name,
            legacy_id,
            extraction_date
        )
        SELECT
            r.id,
            category ->> 'id',
            category ->> 'name',
            category ->> 'legacy_id',
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                ELSE jsonb_build_array(r.payload)
            END
        ) category
        WHERE r.id = :raw_id
    """,
    "results/events": """
        INSERT INTO bronze.motogp_events (
            raw_id,
            event_id,
            event_name,
            official_name,
            country,
            circuit,
            start_date,
            end_date,
            extraction_date
        )
        SELECT
            r.id,
            event ->> 'id',
            event ->> 'name',
            event ->> 'sponsored_name',
            event -> 'country' ->> 'name',
            event -> 'circuit' ->> 'name',
            event ->> 'date_start',
            event ->> 'date_end',
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                ELSE jsonb_build_array(r.payload)
            END
        ) event
        WHERE r.id = :raw_id
    """,
    "results/sessions": """
        INSERT INTO bronze.motogp_sessions (
            raw_id,
            session_id,
            session_name,
            session_type,
            session_date,
            event_id,
            category_id,
            extraction_date
        )
        SELECT
            r.id,
            session ->> 'id',
            session ->> 'name',
            session ->> 'type',
            session ->> 'date',
            r.request_params ->> 'eventUuid',
            r.request_params ->> 'categoryUuid',
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                ELSE jsonb_build_array(r.payload)
            END
        ) session
        WHERE r.id = :raw_id
    """,
    "results/standings": """
        INSERT INTO bronze.motogp_standings (
            raw_id,
            season_id,
            category_id,
            rider_id,
            rider_name,
            team_name,
            position,
            points,
            wins,
            podiums,
            extraction_date
        )
        SELECT
            r.id,
            r.request_params ->> 'seasonUuid',
            r.request_params ->> 'categoryUuid',
            standing -> 'rider' ->> 'id',
            standing -> 'rider' ->> 'full_name',
            standing -> 'team' ->> 'name',
            NULLIF(standing ->> 'position', '')::INTEGER,
            NULLIF(standing ->> 'points', '')::INTEGER,
            NULLIF(standing ->> 'race_wins', '')::INTEGER,
            NULLIF(standing ->> 'podiums', '')::INTEGER,
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(r.payload -> 'classification') standing
        WHERE r.id = :raw_id
    """,
    "riders": """
        INSERT INTO bronze.motogp_riders (
            raw_id,
            rider_id,
            legacy_id,
            rider_name,
            rider_surname,
            nickname,
            country,
            birth_date,
            extraction_date
        )
        SELECT
            r.id,
            rider ->> 'id',
            rider ->> 'legacy_id',
            rider ->> 'name',
            rider ->> 'surname',
            rider ->> 'nickname',
            rider -> 'country' ->> 'name',
            rider ->> 'birth_date',
            r.extraction_date
        FROM raw.motogp_api_raw r
        CROSS JOIN LATERAL jsonb_array_elements(
            CASE
                WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                ELSE jsonb_build_array(r.payload)
            END
        ) rider
        WHERE r.id = :raw_id
    """,
}


def get_db_url() -> str:
    return (
        f"postgresql+psycopg2://{os.getenv('POSTGRES_USER')}:"
        f"{os.getenv('POSTGRES_PASSWORD')}"
        f"@{os.getenv('POSTGRES_HOST')}:"
        f"{os.getenv('POSTGRES_PORT')}/"
        f"{os.getenv('POSTGRES_DB')}"
    )


def get_json(endpoint: str, params: dict | None = None):
    response = requests.get(
        f"{BASE_URL}/{endpoint}",
        params=params,
        timeout=30,
        headers={"User-Agent": "motogp-data-platform"},
    )

    if not response.ok:
        print("URL:", response.url)
        print("STATUS:", response.status_code)
        print("BODY:", response.text[:1000])

    response.raise_for_status()
    return response.json()


def save_raw_file(name: str, payload) -> Path:
    RAW_PATH.mkdir(parents=True, exist_ok=True)

    output_file = RAW_PATH / f"{name}_{datetime.now():%Y%m%d_%H%M%S}.json"

    with open(output_file, "w", encoding="utf-8") as file:
        json.dump(payload, file, ensure_ascii=False, indent=2)

    return output_file


def insert_raw_payload(endpoint: str, payload, params: dict | None = None) -> int:
    engine = create_engine(get_db_url())

    payload_text = json.dumps(payload, ensure_ascii=False)
    params_text = json.dumps(params or {}, ensure_ascii=False)

    print("Inserting into PostgreSQL RAW table")
    print(f"Endpoint: {endpoint}")
    print(f"Payload length: {len(payload_text)}")

    sql = text("""
        INSERT INTO raw.motogp_api_raw (
            endpoint,
            extraction_date,
            request_params,
            payload
        )
        VALUES (
            :endpoint,
            :extraction_date,
            CAST(:request_params AS JSONB),
            CAST(:payload AS JSONB)
        )
        RETURNING id
    """)

    with engine.begin() as conn:
        raw_id = conn.execute(
            sql,
            {
                "endpoint": endpoint,
                "extraction_date": datetime.now(timezone.utc),
                "request_params": params_text,
                "payload": payload_text,
            },
        ).scalar_one()

        print(f"RAW row inserted: {raw_id}")
        return raw_id


def get_bronze_load_sql(endpoint: str) -> str | None:
    if endpoint in BRONZE_LOAD_SQL:
        return BRONZE_LOAD_SQL[endpoint]

    if endpoint.startswith("riders/") and endpoint.endswith("/statistics"):
        return """
            INSERT INTO bronze.motogp_rider_stats (
                raw_id,
                rider_id,
                legacy_id,
                season_year,
                category_name,
                constructor_name,
                starts,
                wins,
                second_positions,
                third_positions,
                podiums,
                poles,
                points,
                championship_position,
                extraction_date
            )
            SELECT
                r.id,
                riders.rider_id,
                split_part(r.endpoint, '/', 2),
                NULLIF(stats ->> 'season', '')::INTEGER,
                stats ->> 'category',
                stats ->> 'constructor',
                NULLIF(stats ->> 'starts', '')::INTEGER,
                NULLIF(stats ->> 'first_position', '')::INTEGER,
                NULLIF(stats ->> 'second_position', '')::INTEGER,
                NULLIF(stats ->> 'third_position', '')::INTEGER,
                NULLIF(stats ->> 'podiums', '')::INTEGER,
                NULLIF(stats ->> 'poles', '')::INTEGER,
                NULLIF(stats ->> 'points', '')::NUMERIC,
                NULLIF(stats ->> 'position', '')::INTEGER,
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                    ELSE jsonb_build_array(r.payload)
                END
            ) stats
            LEFT JOIN LATERAL (
                SELECT rider_id
                FROM bronze.motogp_riders
                WHERE legacy_id = split_part(r.endpoint, '/', 2)
                ORDER BY extraction_date DESC
                LIMIT 1
            ) riders ON true
            WHERE r.id = :raw_id
        """

    if endpoint.startswith("riders/") and endpoint.endswith("/stats"):
        return """
            INSERT INTO bronze.motogp_rider_stats (
                raw_id,
                rider_id,
                legacy_id,
                wins,
                podiums,
                poles,
                fastest_laps,
                world_championships,
                extraction_date
            )
            SELECT
                r.id,
                stats ->> 'rider_id',
                stats ->> 'legacy_id',
                NULLIF(stats ->> 'wins', '')::INTEGER,
                NULLIF(stats ->> 'podiums', '')::INTEGER,
                NULLIF(stats ->> 'poles', '')::INTEGER,
                NULLIF(stats ->> 'fastest_laps', '')::INTEGER,
                NULLIF(stats ->> 'world_championships', '')::INTEGER,
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                    ELSE jsonb_build_array(r.payload)
                END
            ) stats
            WHERE r.id = :raw_id
        """

    if endpoint.startswith("riders/"):
        return """
            INSERT INTO bronze.motogp_rider_details (
                raw_id,
                rider_id,
                legacy_id,
                rider_name,
                rider_surname,
                rider_number,
                country,
                birth_date,
                height,
                weight,
                biography,
                extraction_date
            )
            SELECT
                r.id,
                detail ->> 'id',
                detail ->> 'legacy_id',
                detail ->> 'name',
                detail ->> 'surname',
                detail ->> 'number',
                detail -> 'country' ->> 'name',
                detail ->> 'birth_date',
                detail ->> 'height',
                detail ->> 'weight',
                detail ->> 'biography',
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                    ELSE jsonb_build_array(r.payload)
                END
            ) detail
            WHERE r.id = :raw_id
        """

    if endpoint.startswith("results/event/") and endpoint.endswith("/entry"):
        return """
            INSERT INTO bronze.motogp_entry_list (
                raw_id,
                event_id,
                category_id,
                rider_id,
                rider_name,
                team_name,
                bike,
                rider_number,
                extraction_date
            )
            SELECT
                r.id,
                split_part(r.endpoint, '/', 3),
                r.request_params ->> 'categoryUuid',
                entry -> 'rider' ->> 'id',
                entry -> 'rider' ->> 'full_name',
                entry -> 'team' ->> 'name',
                entry -> 'constructor' ->> 'name',
                entry -> 'rider' ->> 'number',
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                    ELSE jsonb_build_array(r.payload)
                END
            ) entry
            WHERE r.id = :raw_id
        """

    if endpoint.startswith("results/event/") and endpoint.endswith("/grid"):
        return """
            INSERT INTO bronze.motogp_grid (
                raw_id,
                event_id,
                category_id,
                rider_id,
                grid_position,
                lap_time,
                extraction_date
            )
            SELECT
                r.id,
                grid_row -> 'event' ->> 'id',
                grid_row -> 'category' ->> 'id',
                grid_row -> 'rider' ->> 'id',
                NULLIF(grid_row ->> 'qualifying_position', '')::INTEGER,
                grid_row ->> 'qualifying_time',
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(
                CASE
                    WHEN jsonb_typeof(r.payload) = 'array' THEN r.payload
                    ELSE jsonb_build_array(r.payload)
                END
            ) grid_row
            WHERE r.id = :raw_id
        """

    if endpoint.startswith("results/session/") and endpoint.endswith("/classification"):
        return """
            INSERT INTO bronze.motogp_session_classification (
                raw_id,
                session_id,
                rider_id,
                rider_name,
                team_name,
                position,
                points,
                laps,
                total_time,
                gap,
                extraction_date
            )
            SELECT
                r.id,
                split_part(r.endpoint, '/', 3),
                classification -> 'rider' ->> 'id',
                classification -> 'rider' ->> 'full_name',
                classification -> 'team' ->> 'name',
                NULLIF(classification ->> 'position', '')::INTEGER,
                NULLIF(classification ->> 'points', '')::INTEGER,
                NULLIF(classification ->> 'total_laps', '')::INTEGER,
                classification -> 'best_lap' ->> 'time',
                classification -> 'gap' ->> 'first',
                r.extraction_date
            FROM raw.motogp_api_raw r
            CROSS JOIN LATERAL jsonb_array_elements(r.payload -> 'classification') classification
            WHERE r.id = :raw_id
        """

    return None


def load_bronze_table(raw_id: int, endpoint: str) -> None:
    load_sql = get_bronze_load_sql(endpoint)
    if load_sql is None:
        print(f"No bronze loader configured for endpoint: {endpoint}")
        return

    engine = create_engine(get_db_url())
    with engine.begin() as conn:
        result = conn.execute(text(load_sql), {"raw_id": raw_id})

    print(f"Bronze rows inserted for {endpoint}: {result.rowcount}")


def extract_endpoint(
    endpoint: str,
    params: dict | None = None,
    file_name: str | None = None,
    required: bool = True,
):
    try:
        payload = get_json(endpoint, params=params)
    except requests.HTTPError as exc:
        if required:
            raise

        print(f"Skipping endpoint after HTTP error: {endpoint} {params or {}}")
        print(exc)
        return None

    output_name = file_name or endpoint.replace("/", "_")

    file_path = save_raw_file(output_name, payload)
    print(f"File created: {file_path}")

    raw_id = insert_raw_payload(endpoint=endpoint, payload=payload, params=params)
    load_bronze_table(raw_id=raw_id, endpoint=endpoint)

    return payload


def get_season_uuid(seasons, year: int) -> str:
    for season in seasons:
        if season.get("year") == year:
            return season["id"]

    raise ValueError(f"No se encontró season UUID para el año {year}")


def get_all_seasons(seasons) -> list[tuple[int, str]]:
    season_ids = []
    for season in seasons:
        year = season.get("year")
        season_uuid = season.get("id")
        if year is None or season_uuid is None:
            continue
        season_ids.append((int(year), season_uuid))

    return sorted(season_ids)


def load_riders() -> None:
    riders = extract_endpoint("riders")

    for rider in riders:
        legacy_id = rider.get("legacy_id")
        if legacy_id is None:
            continue

        rider_name = rider.get("name", legacy_id)
        rider_surname = rider.get("surname", "")
        print(f"Loading rider statistics for {rider_name} {rider_surname}".strip())
        extract_endpoint(
            f"riders/{legacy_id}/statistics",
            file_name=f"riders_{legacy_id}_statistics",
            required=False,
        )


def load_categories(year: int, season_uuid: str, required: bool = True):
    return extract_endpoint(
        "results/categories",
        params={"seasonUuid": season_uuid},
        file_name=f"results_categories_{year}",
        required=required,
    )


def load_events(year: int, season_uuid: str, required: bool = True):
    return extract_endpoint(
        "results/events",
        params={
            "seasonUuid": season_uuid,
            "isFinished": "true",
        },
        file_name=f"results_events_{year}",
        required=required,
    )


def load_standings(
    year: int,
    season_uuid: str,
    categories,
    required: bool = True,
) -> None:
    for category in categories:
        category_uuid = category["id"]
        category_name = category.get("name", category_uuid)
        print(f"Loading standings for {category_name}")
        extract_endpoint(
            "results/standings",
            params={
                "seasonUuid": season_uuid,
                "categoryUuid": category_uuid,
            },
            file_name=f"results_standings_{year}_{category_uuid}",
            required=required,
        )


def load_sessions(
    events,
    categories,
    required: bool = False,
) -> list[dict]:
    loaded_sessions = []
    for event in events:
        event_uuid = event["id"]
        event_name = event.get("short_name", event_uuid)
        for category in categories:
            category_uuid = category["id"]
            category_name = category.get("name", category_uuid)
            print(f"Loading sessions for {event_name} / {category_name}")
            sessions = extract_endpoint(
                "results/sessions",
                params={
                    "eventUuid": event_uuid,
                    "categoryUuid": category_uuid,
                },
                file_name=f"results_sessions_{event_uuid}_{category_uuid}",
                required=required,
            )
            if sessions:
                loaded_sessions.extend(sessions)

    return loaded_sessions


def load_grid(events, categories) -> None:
    for event in events:
        event_uuid = event["id"]
        event_name = event.get("short_name", event_uuid)
        for category in categories:
            category_uuid = category["id"]
            category_name = category.get("name", category_uuid)
            print(f"Loading grid for {event_name} / {category_name}")
            extract_endpoint(
                f"results/event/{event_uuid}/category/{category_uuid}/grid",
                file_name=f"results_grid_{event_uuid}_{category_uuid}",
                required=False,
            )


def load_classification(sessions) -> None:
    for session in sessions:
        session_uuid = session.get("id")
        if session_uuid is None:
            continue

        session_name = session.get("name", session_uuid)
        print(f"Loading classification for {session_name}")
        extract_endpoint(
            f"results/session/{session_uuid}/classification",
            file_name=f"results_classification_{session_uuid}",
            required=False,
        )


def load_season(
    year: int,
    season_uuid: str,
    resources: set[str],
    required: bool = True,
) -> None:
    print(f"Loading season {year}")
    print(f"Season UUID {year}: {season_uuid}")

    needs_categories = bool(
        resources
        & {
            "result_categories",
            "result_standings",
            "result_sessions",
            "result_grid",
            "result_classification",
        }
    )
    needs_events = bool(
        resources
        & {
            "result_events",
            "result_sessions",
            "result_grid",
            "result_classification",
        }
    )

    categories = (
        load_categories(year, season_uuid, required=required)
        if needs_categories
        else None
    )
    if needs_categories and categories is None:
        print(f"Skipping season {year}: categories not available")
        return

    events = (
        load_events(year, season_uuid, required=required)
        if needs_events
        else None
    )
    if needs_events and events is None:
        print(f"Skipping season {year}: events not available")
        return

    if "result_standings" in resources:
        load_standings(year, season_uuid, categories, required=required)

    sessions = []
    if "result_sessions" in resources or "result_classification" in resources:
        sessions = load_sessions(events, categories)

    if "result_grid" in resources:
        load_grid(events, categories)

    if "result_classification" in resources:
        load_classification(sessions)


def parse_resources(raw_resources: str) -> set[str]:
    if raw_resources == "all":
        return set(DEFAULT_RESOURCES)

    resources = set()
    for resource in raw_resources.split(","):
        resource_name = resource.strip().lower()
        if not resource_name:
            continue

        try:
            resources.add(RESOURCE_ALIASES[resource_name])
        except KeyError as exc:
            allowed_resources = ", ".join(DEFAULT_RESOURCES)
            raise ValueError(
                f"Recurso no soportado: {resource_name}. "
                f"Recursos soportados: {allowed_resources}"
            ) from exc

    return resources


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Carga datos de MotoGP en raw/bronze.",
    )
    parser.add_argument(
        "season",
        nargs="?",
        default=str(DEFAULT_YEAR),
        help=(
            f"Año a cargar o 'all' para cargar todas las temporadas. "
            f"Sin parametro carga {DEFAULT_YEAR}."
        ),
    )
    parser.add_argument(
        "--only",
        default="all",
        help=(
            "Recursos a cargar separados por comas. Opciones: "
            "riders, result_categories, result_events, result_standings, "
            "result_sessions, result_grid, result_classification. "
            "Por defecto carga todos."
        ),
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    season_arg = args.season.lower()
    resources = parse_resources(args.only.lower())

    seasons = extract_endpoint("results/seasons")

    if "riders" in resources:
        load_riders()

    season_resources = resources - {"riders"}
    if not season_resources:
        print("Finished successfully")
        return

    if season_arg == "all":
        for year, season_uuid in get_all_seasons(seasons):
            load_season(
                year,
                season_uuid,
                resources=season_resources,
                required=False,
            )
    else:
        try:
            year = int(args.season)
        except ValueError as exc:
            raise ValueError(
                "El parametro debe ser un año, por ejemplo 2024, o 'all'"
            ) from exc

        season_uuid = get_season_uuid(seasons, year)
        load_season(year, season_uuid, resources=season_resources)

    print("Finished successfully")


if __name__ == "__main__":
    main()

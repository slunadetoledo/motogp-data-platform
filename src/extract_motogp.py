from pathlib import Path
from datetime import datetime, timezone
import json
import os

import requests
from sqlalchemy import create_engine, text


BASE_URL = "https://api.pulselive.motogp.com/motogp/v1"
RAW_PATH = Path("data/raw/motogp")


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


def insert_raw_payload(endpoint: str, payload) -> None:
    engine = create_engine(get_db_url())

    payload_text = json.dumps(payload, ensure_ascii=False)

    print("Inserting into PostgreSQL RAW table")
    print(f"Endpoint: {endpoint}")
    print(f"Payload length: {len(payload_text)}")

    sql = text("""
        INSERT INTO raw.motogp_api_raw (
            endpoint,
            extraction_date,
            payload
        )
        VALUES (
            :endpoint,
            :extraction_date,
            CAST(:payload AS JSONB)
        )
    """)

    with engine.begin() as conn:
        result = conn.execute(
            sql,
            {
                "endpoint": endpoint,
                "extraction_date": datetime.now(timezone.utc),
                "payload": payload_text,
            },
        )

        print(f"Rows inserted: {result.rowcount}")


def get_season_uuid(year: int) -> str:
    seasons = get_json("results/seasons")

    for season in seasons:
        if season.get("year") == year:
            return season["id"]

    raise ValueError(f"No se encontró season UUID para el año {year}")


def main() -> None:
    year = 2024
    endpoint = "results/events"

    season_uuid = get_season_uuid(year)
    print(f"Season UUID {year}: {season_uuid}")

    events = get_json(
        endpoint,
        params={
            "seasonUuid": season_uuid,
            "isFinished": "true",
        },
    )

    file_path = save_raw_file(f"results_events_{year}", events)
    print(f"File created: {file_path}")

    insert_raw_payload(
        endpoint=endpoint,
        payload=events,
    )

    print("Finished successfully")


if __name__ == "__main__":
    main()

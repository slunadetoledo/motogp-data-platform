CREATE TABLE IF NOT EXISTS raw.motogp_api_raw (
    id BIGSERIAL PRIMARY KEY,
    endpoint VARCHAR(255) NOT NULL,
    extraction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    request_params JSONB NOT NULL DEFAULT '{}'::jsonb,
    payload JSONB NOT NULL
);

ALTER TABLE raw.motogp_api_raw
ADD COLUMN IF NOT EXISTS request_params JSONB NOT NULL DEFAULT '{}'::jsonb;

DROP VIEW IF EXISTS bronze.vw_motogp_standings;
DROP VIEW IF EXISTS bronze.vw_motogp_session_classification;
DROP VIEW IF EXISTS bronze.vw_motogp_grid;
DROP VIEW IF EXISTS bronze.vw_motogp_entry_list;
DROP VIEW IF EXISTS bronze.vw_motogp_rider_stats;
DROP VIEW IF EXISTS bronze.vw_motogp_rider_details;
DROP VIEW IF EXISTS bronze.vw_motogp_riders;
DROP VIEW IF EXISTS bronze.vw_motogp_sessions;
DROP VIEW IF EXISTS bronze.vw_motogp_events;
DROP VIEW IF EXISTS bronze.vw_motogp_categories;
DROP VIEW IF EXISTS bronze.vw_motogp_seasons;

CREATE TABLE IF NOT EXISTS bronze.motogp_seasons (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    season_id TEXT,
    season_year INTEGER,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_categories (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    category_id TEXT,
    category_name TEXT,
    legacy_id TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_events (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    event_id TEXT,
    event_name TEXT,
    official_name TEXT,
    country TEXT,
    circuit TEXT,
    start_date TEXT,
    end_date TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_sessions (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    session_id TEXT,
    session_name TEXT,
    session_type TEXT,
    session_date TEXT,
    event_id TEXT,
    category_id TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_riders (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    rider_id TEXT,
    legacy_id TEXT,
    rider_name TEXT,
    rider_surname TEXT,
    nickname TEXT,
    country TEXT,
    birth_date TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_rider_details (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    rider_id TEXT,
    legacy_id TEXT,
    rider_name TEXT,
    rider_surname TEXT,
    rider_number TEXT,
    country TEXT,
    birth_date TEXT,
    height TEXT,
    weight TEXT,
    biography TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_rider_stats (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    rider_id TEXT,
    legacy_id TEXT,
    season_year INTEGER,
    category_name TEXT,
    constructor_name TEXT,
    starts INTEGER,
    wins INTEGER,
    second_positions INTEGER,
    third_positions INTEGER,
    podiums INTEGER,
    poles INTEGER,
    points NUMERIC,
    championship_position INTEGER,
    fastest_laps INTEGER,
    world_championships INTEGER,
    extraction_date TIMESTAMPTZ NOT NULL
);

ALTER TABLE bronze.motogp_rider_stats
ADD COLUMN IF NOT EXISTS season_year INTEGER,
ADD COLUMN IF NOT EXISTS category_name TEXT,
ADD COLUMN IF NOT EXISTS constructor_name TEXT,
ADD COLUMN IF NOT EXISTS starts INTEGER,
ADD COLUMN IF NOT EXISTS second_positions INTEGER,
ADD COLUMN IF NOT EXISTS third_positions INTEGER,
ADD COLUMN IF NOT EXISTS points NUMERIC,
ADD COLUMN IF NOT EXISTS championship_position INTEGER;

ALTER TABLE bronze.motogp_rider_stats
ALTER COLUMN points TYPE NUMERIC;

CREATE TABLE IF NOT EXISTS bronze.motogp_entry_list (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    event_id TEXT,
    category_id TEXT,
    rider_id TEXT,
    rider_name TEXT,
    team_name TEXT,
    bike TEXT,
    rider_number TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_grid (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    event_id TEXT,
    category_id TEXT,
    rider_id TEXT,
    grid_position INTEGER,
    lap_time TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_session_classification (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    session_id TEXT,
    rider_id TEXT,
    rider_name TEXT,
    team_name TEXT,
    position INTEGER,
    points INTEGER,
    laps INTEGER,
    total_time TEXT,
    gap TEXT,
    extraction_date TIMESTAMPTZ NOT NULL
);

CREATE TABLE IF NOT EXISTS bronze.motogp_standings (
    raw_id BIGINT REFERENCES raw.motogp_api_raw(id),
    season_id TEXT,
    category_id TEXT,
    rider_id TEXT,
    rider_name TEXT,
    team_name TEXT,
    position INTEGER,
    points NUMERIC,
    wins INTEGER,
    podiums INTEGER,
    extraction_date TIMESTAMPTZ NOT NULL
);

ALTER TABLE bronze.motogp_standings
ALTER COLUMN points TYPE NUMERIC;

CREATE TABLE IF NOT EXISTS raw.motogp_api_raw (
    id BIGSERIAL PRIMARY KEY,
    endpoint VARCHAR(255) NOT NULL,
    extraction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    payload JSONB NOT NULL
);

CREATE OR REPLACE VIEW bronze.vw_motogp_seasons AS
SELECT
    season ->> 'id' AS season_id,
    (season ->> 'year')::INTEGER AS season_year,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) season
WHERE r.endpoint = 'results/seasons';

CREATE OR REPLACE VIEW bronze.vw_motogp_categories AS
SELECT
    category ->> 'id' AS category_id,
    category ->> 'name' AS category_name,
    category ->> 'legacy_id' AS legacy_id,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) category
WHERE r.endpoint = 'results/categories';

CREATE OR REPLACE VIEW bronze.vw_motogp_events AS
SELECT
    event ->> 'id' AS event_id,
    event ->> 'name' AS event_name,
    event ->> 'official_name' AS official_name,
    event ->> 'country' AS country,
    event ->> 'circuit' AS circuit,
    event ->> 'start_date' AS start_date,
    event ->> 'end_date' AS end_date,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) event
WHERE r.endpoint = 'results/events';

CREATE OR REPLACE VIEW bronze.vw_motogp_sessions AS
SELECT
    session ->> 'id' AS session_id,
    session ->> 'name' AS session_name,
    session ->> 'type' AS session_type,
    session ->> 'date' AS session_date,
    session ->> 'event_id' AS event_id,
    session ->> 'category_id' AS category_id,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) session
WHERE r.endpoint = 'results/sessions';

CREATE OR REPLACE VIEW bronze.vw_motogp_riders AS
SELECT
    rider ->> 'id' AS rider_id,
    rider ->> 'legacy_id' AS legacy_id,
    rider ->> 'name' AS rider_name,
    rider ->> 'surname' AS rider_surname,
    rider ->> 'nickname' AS nickname,
    rider ->> 'country' AS country,
    rider ->> 'birth_date' AS birth_date,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) rider
WHERE r.endpoint = 'riders';

CREATE OR REPLACE VIEW bronze.vw_motogp_rider_details AS
SELECT
    detail ->> 'id' AS rider_id,
    detail ->> 'legacy_id' AS legacy_id,
    detail ->> 'name' AS rider_name,
    detail ->> 'surname' AS rider_surname,
    detail ->> 'number' AS rider_number,
    detail ->> 'country' AS country,
    detail ->> 'birth_date' AS birth_date,
    detail ->> 'height' AS height,
    detail ->> 'weight' AS weight,
    detail ->> 'biography' AS biography,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) detail
WHERE r.endpoint LIKE 'riders/%'
  AND r.endpoint NOT LIKE '%/stats';

CREATE OR REPLACE VIEW bronze.vw_motogp_rider_stats AS
SELECT
    stats ->> 'rider_id' AS rider_id,
    stats ->> 'legacy_id' AS legacy_id,
    (stats ->> 'wins')::INTEGER AS wins,
    (stats ->> 'podiums')::INTEGER AS podiums,
    (stats ->> 'poles')::INTEGER AS poles,
    (stats ->> 'fastest_laps')::INTEGER AS fastest_laps,
    (stats ->> 'world_championships')::INTEGER AS world_championships,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) stats
WHERE r.endpoint LIKE 'riders/%/stats';

CREATE OR REPLACE VIEW bronze.vw_motogp_entry_list AS
SELECT
    entry ->> 'event_id' AS event_id,
    entry ->> 'category_id' AS category_id,
    entry ->> 'rider_id' AS rider_id,
    entry ->> 'rider_name' AS rider_name,
    entry ->> 'team_name' AS team_name,
    entry ->> 'bike' AS bike,
    entry ->> 'number' AS rider_number,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) entry
WHERE r.endpoint LIKE 'event/%/entry%';

CREATE OR REPLACE VIEW bronze.vw_motogp_grid AS
SELECT
    grid_row ->> 'event_id' AS event_id,
    grid_row ->> 'category_id' AS category_id,
    grid_row ->> 'rider_id' AS rider_id,
    (grid_row ->> 'position')::INTEGER AS grid_position,
    grid_row ->> 'time' AS lap_time,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) grid_row
WHERE r.endpoint LIKE 'results/event/%/category/%/grid';

CREATE OR REPLACE VIEW bronze.vw_motogp_session_classification AS
SELECT
    classification ->> 'session_id' AS session_id,
    classification ->> 'rider_id' AS rider_id,
    classification ->> 'rider_name' AS rider_name,
    classification ->> 'team_name' AS team_name,
    (classification ->> 'position')::INTEGER AS position,
    (classification ->> 'points')::INTEGER AS points,
    (classification ->> 'laps')::INTEGER AS laps,
    classification ->> 'time' AS total_time,
    classification ->> 'gap' AS gap,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) classification
WHERE r.endpoint LIKE 'results/session/%/classification';

CREATE OR REPLACE VIEW bronze.vw_motogp_standings AS
SELECT
    standing ->> 'season_id' AS season_id,
    standing ->> 'category_id' AS category_id,
    standing ->> 'rider_id' AS rider_id,
    standing ->> 'rider_name' AS rider_name,
    standing ->> 'team_name' AS team_name,
    (standing ->> 'position')::INTEGER AS position,
    (standing ->> 'points')::INTEGER AS points,
    (standing ->> 'wins')::INTEGER AS wins,
    (standing ->> 'podiums')::INTEGER AS podiums,
    r.extraction_date
FROM raw.motogp_api_raw r
CROSS JOIN LATERAL jsonb_array_elements(r.payload) standing
WHERE r.endpoint = 'results/standings';

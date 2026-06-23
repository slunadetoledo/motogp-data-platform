select
    event_id,
    event_name,
    official_name,
    country,
    circuit,
    start_date,
    end_date
from {{ ref('stg_events') }}

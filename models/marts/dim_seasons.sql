select
    season_id,
    season_year
from {{ ref('stg_seasons') }}

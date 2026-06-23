select
    g.event_id,
    g.category_id,
    g.rider_id,
    g.grid_position,
    g.qualifying_time
from {{ ref('stg_grid') }} g

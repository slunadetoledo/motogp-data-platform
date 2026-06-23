select
    s.session_id,
    s.session_name,
    s.session_type,
    s.session_datetime,
    s.event_id,
    e.event_name,
    s.category_id,
    c.category_name
from {{ ref('stg_sessions') }} s
left join {{ ref('dim_events') }} e
    on s.event_id = e.event_id
left join {{ ref('dim_categories') }} c
    on s.category_id = c.category_id

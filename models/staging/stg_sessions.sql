with ranked as (
    select
        session_id,
        session_name,
        session_type,
        nullif(session_date, '')::timestamptz as session_datetime,
        event_id,
        category_id,
        extraction_date,
        row_number() over (
            partition by session_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from {{ source('bronze', 'motogp_sessions') }}
    where session_id is not null
)

select
    session_id,
    session_name,
    session_type,
    session_datetime,
    event_id,
    category_id,
    extraction_date
from ranked
where row_num = 1

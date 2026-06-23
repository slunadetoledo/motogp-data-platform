with ranked as (
    select
        event_id,
        event_name,
        official_name,
        country,
        circuit,
        nullif(start_date, '')::date as start_date,
        nullif(end_date, '')::date as end_date,
        extraction_date,
        row_number() over (
            partition by event_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from "motogp"."bronze"."motogp_events"
    where event_id is not null
)

select
    event_id,
    event_name,
    official_name,
    country,
    circuit,
    start_date,
    end_date,
    extraction_date
from ranked
where row_num = 1
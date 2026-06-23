with expanded as (
    select
        r.id as raw_id,
        grid_row,
        r.extraction_date
    from {{ source('raw', 'motogp_api_raw') }} r
    cross join lateral jsonb_array_elements(r.payload) grid_row
    where r.endpoint like 'results/event/%/category/%/grid'
),

ranked as (
    select
        grid_row -> 'event' ->> 'id' as event_id,
        grid_row -> 'category' ->> 'id' as category_id,
        coalesce(
            grid_row -> 'rider' ->> 'riders_api_uuid',
            grid_row -> 'rider' ->> 'riders_id',
            grid_row -> 'rider' ->> 'id'
        ) as rider_id,
        nullif(grid_row ->> 'qualifying_position', '')::integer as grid_position,
        grid_row ->> 'qualifying_time' as qualifying_time,
        extraction_date,
        row_number() over (
            partition by
                grid_row -> 'event' ->> 'id',
                grid_row -> 'category' ->> 'id',
                coalesce(
                    grid_row -> 'rider' ->> 'riders_api_uuid',
                    grid_row -> 'rider' ->> 'riders_id',
                    grid_row -> 'rider' ->> 'id'
                )
            order by extraction_date desc, raw_id desc
        ) as row_num
    from expanded
)

select
    event_id,
    category_id,
    rider_id,
    grid_position,
    qualifying_time,
    extraction_date
from ranked
where row_num = 1
  and event_id is not null
  and category_id is not null
  and rider_id is not null

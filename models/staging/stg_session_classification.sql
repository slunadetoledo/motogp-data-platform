with expanded as (
    select
        r.id as raw_id,
        split_part(r.endpoint, '/', 3) as session_id,
        classification,
        r.extraction_date
    from {{ source('raw', 'motogp_api_raw') }} r
    cross join lateral jsonb_array_elements(r.payload -> 'classification') classification
    where r.endpoint like 'results/session/%/classification'
      and jsonb_typeof(r.payload -> 'classification') = 'array'
),

ranked as (
    select
        session_id,
        coalesce(
            classification -> 'rider' ->> 'riders_api_uuid',
            classification -> 'rider' ->> 'riders_id',
            classification -> 'rider' ->> 'id'
        ) as rider_id,
        classification -> 'rider' ->> 'full_name' as rider_name,
        classification -> 'team' ->> 'name' as team_name,
        nullif(classification ->> 'position', '')::integer as position,
        nullif(classification ->> 'points', '')::integer as points,
        nullif(classification ->> 'total_laps', '')::integer as laps,
        classification -> 'best_lap' ->> 'time' as total_time,
        classification -> 'gap' ->> 'first' as gap,
        extraction_date,
        row_number() over (
            partition by
                session_id,
                coalesce(
                    classification -> 'rider' ->> 'riders_api_uuid',
                    classification -> 'rider' ->> 'riders_id',
                    classification -> 'rider' ->> 'id'
                )
            order by extraction_date desc, raw_id desc
        ) as row_num
    from expanded
)

select
    session_id,
    rider_id,
    rider_name,
    team_name,
    position,
    points,
    laps,
    total_time,
    gap,
    extraction_date
from ranked
where row_num = 1
  and session_id is not null
  and rider_id is not null

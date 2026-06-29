with expanded as (
    select
        r.id as raw_id,
        r.request_params ->> 'seasonUuid' as season_id,
        r.request_params ->> 'categoryUuid' as category_id,
        standing,
        r.extraction_date
    from "motogp"."raw"."motogp_api_raw" r
    cross join lateral jsonb_array_elements(r.payload -> 'classification') standing
    where r.endpoint = 'results/standings'
      and jsonb_typeof(r.payload -> 'classification') = 'array'
),

ranked as (
    select
        season_id,
        category_id,
        coalesce(
            standing -> 'rider' ->> 'riders_api_uuid',
            standing -> 'rider' ->> 'riders_id',
            standing -> 'rider' ->> 'id'
        ) as rider_id,
        standing -> 'rider' ->> 'full_name' as rider_name,
        standing -> 'team' ->> 'name' as team_name,
        nullif(standing ->> 'position', '')::integer as position,
        nullif(standing ->> 'points', '')::numeric as points,
        nullif(standing ->> 'race_wins', '')::integer as wins,
        nullif(standing ->> 'podiums', '')::integer as podiums,
        extraction_date,
        row_number() over (
            partition by
                season_id,
                category_id,
                coalesce(
                    standing -> 'rider' ->> 'riders_api_uuid',
                    standing -> 'rider' ->> 'riders_id',
                    standing -> 'rider' ->> 'id'
                )
            order by extraction_date desc, raw_id desc
        ) as row_num
    from expanded
)

select
    season_id,
    category_id,
    rider_id,
    rider_name,
    team_name,
    position,
    points,
    wins,
    podiums,
    extraction_date
from ranked
where row_num = 1
  and season_id is not null
  and category_id is not null
  and rider_id is not null
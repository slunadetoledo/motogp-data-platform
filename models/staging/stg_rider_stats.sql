with ranked as (
    select
        rider_id,
        legacy_id,
        season_year,
        category_name,
        constructor_name,
        starts,
        wins,
        second_positions,
        third_positions,
        podiums,
        poles,
        points,
        championship_position,
        fastest_laps,
        world_championships,
        extraction_date,
        row_number() over (
            partition by coalesce(rider_id, legacy_id), season_year, category_name
            order by extraction_date desc, raw_id desc
        ) as row_num
    from {{ source('bronze', 'motogp_rider_stats') }}
    where season_year is not null
      and category_name is not null
)

select
    rider_id,
    legacy_id,
    season_year,
    category_name,
    constructor_name,
    starts,
    wins,
    second_positions,
    third_positions,
    podiums,
    poles,
    points,
    championship_position,
    fastest_laps,
    world_championships,
    extraction_date
from ranked
where row_num = 1

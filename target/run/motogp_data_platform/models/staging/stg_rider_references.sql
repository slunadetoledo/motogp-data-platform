
  create view "motogp"."silver"."stg_rider_references__dbt_tmp"
    
    
  as (
    with base_riders as (
    select
        rider_id,
        legacy_id,
        rider_name,
        rider_surname,
        nickname,
        country,
        birth_date,
        extraction_date,
        1 as source_priority
    from "motogp"."silver"."stg_riders"

    union all

    select
        rider_id,
        legacy_id,
        rider_name,
        rider_surname,
        null as nickname,
        country,
        birth_date,
        extraction_date,
        1 as source_priority
    from "motogp"."silver"."stg_rider_details"
),

grid_riders as (
    select
        coalesce(
            grid_row -> 'rider' ->> 'riders_api_uuid',
            grid_row -> 'rider' ->> 'riders_id',
            grid_row -> 'rider' ->> 'id'
        ) as rider_id,
        grid_row -> 'rider' ->> 'legacy_id' as legacy_id,
        grid_row -> 'rider' ->> 'full_name' as rider_name,
        null as rider_surname,
        null as nickname,
        grid_row -> 'rider' -> 'country' ->> 'name' as country,
        null::date as birth_date,
        r.extraction_date,
        2 as source_priority
    from "motogp"."raw"."motogp_api_raw" r
    cross join lateral jsonb_array_elements(r.payload) grid_row
    where r.endpoint like 'results/event/%/category/%/grid'
      and jsonb_typeof(r.payload) = 'array'
),

classification_riders as (
    select
        coalesce(
            classification -> 'rider' ->> 'riders_api_uuid',
            classification -> 'rider' ->> 'riders_id',
            classification -> 'rider' ->> 'id'
        ) as rider_id,
        classification -> 'rider' ->> 'legacy_id' as legacy_id,
        classification -> 'rider' ->> 'full_name' as rider_name,
        null as rider_surname,
        null as nickname,
        classification -> 'rider' -> 'country' ->> 'name' as country,
        null::date as birth_date,
        r.extraction_date,
        3 as source_priority
    from "motogp"."raw"."motogp_api_raw" r
    cross join lateral jsonb_array_elements(r.payload -> 'classification') classification
    where r.endpoint like 'results/session/%/classification'
      and jsonb_typeof(r.payload -> 'classification') = 'array'
),

standing_riders as (
    select
        coalesce(
            standing -> 'rider' ->> 'riders_api_uuid',
            standing -> 'rider' ->> 'riders_id',
            standing -> 'rider' ->> 'id'
        ) as rider_id,
        standing -> 'rider' ->> 'legacy_id' as legacy_id,
        standing -> 'rider' ->> 'full_name' as rider_name,
        null as rider_surname,
        null as nickname,
        standing -> 'rider' -> 'country' ->> 'name' as country,
        null::date as birth_date,
        r.extraction_date,
        4 as source_priority
    from "motogp"."raw"."motogp_api_raw" r
    cross join lateral jsonb_array_elements(r.payload -> 'classification') standing
    where r.endpoint = 'results/standings'
      and jsonb_typeof(r.payload -> 'classification') = 'array'
),

unioned as (
    select * from base_riders
    union all
    select * from grid_riders
    union all
    select * from classification_riders
    union all
    select * from standing_riders
),

ranked as (
    select
        rider_id,
        legacy_id,
        rider_name,
        rider_surname,
        nickname,
        country,
        birth_date,
        extraction_date,
        row_number() over (
            partition by rider_id
            order by source_priority asc, extraction_date desc
        ) as row_num
    from unioned
    where rider_id is not null
)

select
    rider_id,
    legacy_id,
    rider_name,
    rider_surname,
    nickname,
    country,
    birth_date,
    extraction_date
from ranked
where row_num = 1
  );
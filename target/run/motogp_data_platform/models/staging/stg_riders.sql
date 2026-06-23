
  create view "motogp"."silver"."stg_riders__dbt_tmp"
    
    
  as (
    with ranked as (
    select
        rider_id,
        legacy_id,
        rider_name,
        rider_surname,
        nickname,
        country,
        nullif(birth_date, '')::date as birth_date,
        extraction_date,
        row_number() over (
            partition by rider_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from "motogp"."bronze"."motogp_riders"
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
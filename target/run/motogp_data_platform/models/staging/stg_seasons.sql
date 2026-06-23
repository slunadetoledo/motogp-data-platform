
  create view "motogp"."silver"."stg_seasons__dbt_tmp"
    
    
  as (
    with ranked as (
    select
        season_id,
        season_year,
        extraction_date,
        row_number() over (
            partition by season_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from "motogp"."bronze"."motogp_seasons"
    where season_id is not null
)

select
    season_id,
    season_year,
    extraction_date
from ranked
where row_num = 1
  );
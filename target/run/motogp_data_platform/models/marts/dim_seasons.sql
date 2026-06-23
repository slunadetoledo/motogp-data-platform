
  
    

  create  table "motogp"."gold"."dim_seasons__dbt_tmp"
  
  
    as
  
  (
    select
    season_id,
    season_year
from "motogp"."silver"."stg_seasons"
  );
  
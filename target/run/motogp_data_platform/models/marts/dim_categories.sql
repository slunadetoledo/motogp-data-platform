
  
    

  create  table "motogp"."gold"."dim_categories__dbt_tmp"
  
  
    as
  
  (
    select
    category_id,
    category_name,
    legacy_id as category_legacy_id
from "motogp"."silver"."stg_categories"
  );
  
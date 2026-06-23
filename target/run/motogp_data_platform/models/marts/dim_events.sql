
  
    

  create  table "motogp"."gold"."dim_events__dbt_tmp"
  
  
    as
  
  (
    select
    event_id,
    event_name,
    official_name,
    country,
    circuit,
    start_date,
    end_date
from "motogp"."silver"."stg_events"
  );
  

  
    

  create  table "motogp"."gold"."fact_event_grid__dbt_tmp"
  
  
    as
  
  (
    select
    g.event_id,
    g.category_id,
    g.rider_id,
    g.grid_position,
    g.qualifying_time
from "motogp"."silver"."stg_grid" g
  );
  
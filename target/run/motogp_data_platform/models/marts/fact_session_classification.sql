
  
    

  create  table "motogp"."gold"."fact_session_classification__dbt_tmp"
  
  
    as
  
  (
    select
    c.session_id,
    s.event_id,
    s.category_id,
    c.rider_id,
    c.team_name,
    c.position,
    c.points,
    c.laps,
    c.total_time,
    c.gap
from "motogp"."silver"."stg_session_classification" c
left join "motogp"."gold"."dim_sessions" s
    on c.session_id = s.session_id
  );
  
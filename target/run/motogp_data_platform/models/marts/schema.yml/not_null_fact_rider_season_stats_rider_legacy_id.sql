
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select rider_legacy_id
from "motogp"."gold"."fact_rider_season_stats"
where rider_legacy_id is null



  
  
      
    ) dbt_internal_test
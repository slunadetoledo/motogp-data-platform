
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select rider_id
from "motogp"."gold"."fact_session_classification"
where rider_id is null



  
  
      
    ) dbt_internal_test
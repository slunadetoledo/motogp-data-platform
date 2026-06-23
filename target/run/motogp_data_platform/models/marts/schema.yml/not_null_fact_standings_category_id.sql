
    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select category_id
from "motogp"."gold"."fact_standings"
where category_id is null



  
  
      
    ) dbt_internal_test

    
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    rider_id as unique_field,
    count(*) as n_records

from "motogp"."gold"."dim_riders"
where rider_id is not null
group by rider_id
having count(*) > 1



  
  
      
    ) dbt_internal_test
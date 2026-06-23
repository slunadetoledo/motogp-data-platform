
    
    

with child as (
    select event_id as from_field
    from "motogp"."gold"."fact_event_grid"
    where event_id is not null
),

parent as (
    select event_id as to_field
    from "motogp"."gold"."dim_events"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null



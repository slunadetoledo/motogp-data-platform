with ranked as (
    select
        rider_id,
        legacy_id,
        rider_name,
        rider_surname,
        rider_number,
        country,
        nullif(birth_date, '')::date as birth_date,
        height,
        weight,
        biography,
        extraction_date,
        row_number() over (
            partition by rider_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from "motogp"."bronze"."motogp_rider_details"
    where rider_id is not null
)

select
    rider_id,
    legacy_id,
    rider_name,
    rider_surname,
    rider_number,
    country,
    birth_date,
    height,
    weight,
    biography,
    extraction_date
from ranked
where row_num = 1
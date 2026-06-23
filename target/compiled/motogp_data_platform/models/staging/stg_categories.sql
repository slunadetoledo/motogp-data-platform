with ranked as (
    select
        category_id,
        category_name,
        legacy_id,
        extraction_date,
        row_number() over (
            partition by category_id
            order by extraction_date desc, raw_id desc
        ) as row_num
    from "motogp"."bronze"."motogp_categories"
    where category_id is not null
)

select
    category_id,
    category_name,
    legacy_id,
    extraction_date
from ranked
where row_num = 1
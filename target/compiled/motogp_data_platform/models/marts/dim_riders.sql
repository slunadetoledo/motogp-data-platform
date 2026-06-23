select
    r.rider_id,
    coalesce(d.legacy_id, r.legacy_id) as rider_legacy_id,
    coalesce(d.rider_name, r.rider_name) as rider_name,
    coalesce(d.rider_surname, r.rider_surname) as rider_surname,
    r.nickname,
    d.rider_number,
    coalesce(d.country, r.country) as country,
    coalesce(d.birth_date, r.birth_date) as birth_date,
    d.height,
    d.weight,
    d.biography
from "motogp"."silver"."stg_rider_references" r
left join "motogp"."silver"."stg_rider_details" d
    on r.rider_id = d.rider_id
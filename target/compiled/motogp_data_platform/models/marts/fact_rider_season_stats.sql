select
    s.rider_id,
    s.legacy_id as rider_legacy_id,
    s.season_year,
    s.category_name,
    s.constructor_name,
    s.starts,
    s.wins,
    s.second_positions,
    s.third_positions,
    s.podiums,
    s.poles,
    s.points,
    s.championship_position,
    s.fastest_laps,
    s.world_championships
from "motogp"."silver"."stg_rider_stats" s
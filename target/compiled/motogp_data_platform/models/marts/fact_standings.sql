select
    st.season_id,
    se.season_year,
    st.category_id,
    st.rider_id,
    st.team_name,
    st.position,
    st.points,
    st.wins,
    st.podiums
from "motogp"."silver"."stg_standings" st
left join "motogp"."gold"."dim_seasons" se
    on st.season_id = se.season_id
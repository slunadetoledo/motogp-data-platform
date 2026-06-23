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
from {{ ref('stg_standings') }} st
left join {{ ref('dim_seasons') }} se
    on st.season_id = se.season_id

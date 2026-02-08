with teams as (
    select * from {{ ref('stg_teams') }}
)

select
    team_id,
    team_full_name,
    team_code,
    team_abbreviation,
    team_name,
    location_name,
    league_id,
    league_name,
    division_id,
    division_name,
    venue_id,
    venue_name,
    sport_id,
    is_active,
    first_year_of_play
from teams

with players as (
    select * from {{ ref('stg_players') }}
),

teams as (
    select
        team_id,
        team_full_name as current_team_name,
        team_abbreviation as current_team_abbreviation
    from {{ ref('stg_teams') }}
)

select
    p.player_id,
    p.full_name,
    p.first_name,
    p.last_name,
    p.jersey_number,
    p.birth_date,
    p.birth_city,
    p.birth_country,
    p.height,
    p.weight,
    p.position_code,
    p.position_name,
    p.position_type,
    p.bat_side,
    p.pitch_hand,
    p.current_team_id,
    t.current_team_name,
    t.current_team_abbreviation,
    p.mlb_debut_date,
    p.is_active
from players p
left join teams t on p.current_team_id = t.team_id

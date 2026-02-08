with games as (
    select * from {{ ref('stg_games') }}
    where game_status_code = 'F'
),

home_teams as (
    select team_id, team_full_name, team_abbreviation
    from {{ ref('stg_teams') }}
),

away_teams as (
    select team_id, team_full_name, team_abbreviation
    from {{ ref('stg_teams') }}
),

winning_pitchers as (
    select player_id, full_name
    from {{ ref('stg_players') }}
),

losing_pitchers as (
    select player_id, full_name
    from {{ ref('stg_players') }}
),

save_pitchers as (
    select player_id, full_name
    from {{ ref('stg_players') }}
)

select
    g.game_pk,
    g.game_type,
    g.season,
    g.game_date,
    g.game_datetime,
    g.home_team_id,
    ht.team_full_name   as home_team_name,
    ht.team_abbreviation as home_team_abbreviation,
    g.away_team_id,
    at.team_full_name   as away_team_name,
    at.team_abbreviation as away_team_abbreviation,
    g.home_score,
    g.away_score,
    abs(g.home_score - g.away_score) as run_margin,
    case when g.home_score > g.away_score then 'home' else 'away' end as winner,
    case
        when g.home_score > g.away_score then g.home_team_id
        else g.away_team_id
    end as winning_team_id,
    case
        when g.home_score > g.away_score then g.away_team_id
        else g.home_team_id
    end as losing_team_id,
    g.winning_pitcher_id,
    wp.full_name        as winning_pitcher_name,
    g.losing_pitcher_id,
    lp.full_name        as losing_pitcher_name,
    g.save_pitcher_id,
    sp.full_name        as save_pitcher_name,
    g.innings,
    case when g.innings > 9 then true else false end as is_extra_innings,
    g.venue_id,
    g.venue_name,
    g.day_night,
    g.series_description,
    g.series_game_number,
    g.double_header
from games g
left join home_teams ht on g.home_team_id = ht.team_id
left join away_teams at on g.away_team_id = at.team_id
left join winning_pitchers wp on g.winning_pitcher_id = wp.player_id
left join losing_pitchers lp on g.losing_pitcher_id = lp.player_id
left join save_pitchers sp on g.save_pitcher_id = sp.player_id

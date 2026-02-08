with games as (
    select * from {{ ref('stg_games') }}
    where game_status_code = 'F'
),

home_games as (
    select
        game_pk,
        game_type,
        season,
        game_date,
        game_datetime,
        true                as is_home,
        home_team_id        as team_id,
        away_team_id        as opponent_id,
        home_score          as runs_scored,
        away_score          as runs_allowed,
        case when home_score > away_score then true else false end as is_win,
        case when home_score < away_score then true else false end as is_loss,
        venue_id,
        venue_name,
        winning_pitcher_id,
        losing_pitcher_id,
        save_pitcher_id,
        innings,
        day_night,
        series_description,
        series_game_number,
        double_header
    from games
    where home_score is not null and away_score is not null
),

away_games as (
    select
        game_pk,
        game_type,
        season,
        game_date,
        game_datetime,
        false               as is_home,
        away_team_id        as team_id,
        home_team_id        as opponent_id,
        away_score          as runs_scored,
        home_score          as runs_allowed,
        case when away_score > home_score then true else false end as is_win,
        case when away_score < home_score then true else false end as is_loss,
        venue_id,
        venue_name,
        winning_pitcher_id,
        losing_pitcher_id,
        save_pitcher_id,
        innings,
        day_night,
        series_description,
        series_game_number,
        double_header
    from games
    where home_score is not null and away_score is not null
),

unioned as (
    select * from home_games
    union all
    select * from away_games
)

select * from unioned

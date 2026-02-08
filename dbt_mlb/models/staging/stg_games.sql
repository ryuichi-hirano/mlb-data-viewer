with source as (
    select * from {{ source('raw_mlb', 'raw_games') }}
),

renamed as (
    select
        game_pk,
        game_type,
        season,
        game_date,
        game_datetime,
        status_code         as game_status_code,
        status_detail       as game_status_detail,
        home_team_id,
        away_team_id,
        home_score,
        away_score,
        home_wins,
        home_losses,
        away_wins,
        away_losses,
        venue_id,
        venue_name,
        winning_pitcher_id,
        losing_pitcher_id,
        save_pitcher_id,
        innings,
        day_night,
        series_description,
        series_game_number,
        double_header,
        loaded_at

    from source
)

select * from renamed

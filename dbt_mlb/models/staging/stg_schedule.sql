with source as (
    select * from {{ source('raw_mlb', 'raw_schedule') }}
),

renamed as (
    select
        id                  as schedule_id,
        game_pk,
        game_date,
        game_type,
        season,
        status_code         as game_status_code,
        status_detail       as game_status_detail,
        home_team_id,
        home_team_name,
        away_team_id,
        away_team_name,
        venue_id,
        venue_name,
        game_datetime,
        day_night,
        series_description,
        series_game_number,
        games_in_series,
        double_header,
        scheduled_innings,
        loaded_at

    from source
)

select * from renamed

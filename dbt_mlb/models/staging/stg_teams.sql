with source as (
    select * from {{ source('raw_mlb', 'raw_teams') }}
),

renamed as (
    select
        team_id,
        name                as team_full_name,
        team_code,
        abbreviation        as team_abbreviation,
        team_name,
        location_name,
        league_id,
        league_name,
        division_id,
        division_name,
        venue_id,
        venue_name,
        sport_id,
        active              as is_active,
        first_year_of_play::integer as first_year_of_play,
        loaded_at

    from source
)

select * from renamed

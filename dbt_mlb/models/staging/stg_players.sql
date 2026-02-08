with source as (
    select * from {{ source('raw_mlb', 'raw_players') }}
),

renamed as (
    select
        player_id,
        full_name,
        first_name,
        last_name,
        primary_number      as jersey_number,
        birth_date,
        birth_city,
        birth_country,
        height,
        weight,
        primary_position_code   as position_code,
        primary_position_name   as position_name,
        primary_position_type   as position_type,
        bat_side,
        pitch_hand,
        current_team_id,
        mlb_debut_date,
        active              as is_active,
        loaded_at

    from source
)

select * from renamed

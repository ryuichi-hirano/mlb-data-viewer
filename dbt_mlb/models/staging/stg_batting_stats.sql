with source as (
    select * from {{ source('raw_mlb', 'raw_batting_stats') }}
),

renamed as (
    select
        id                  as batting_stats_id,
        player_id,
        season,
        team_id,
        league_id,
        game_type,
        games_played,
        at_bats,
        runs,
        hits,
        doubles,
        triples,
        home_runs,
        rbi,
        stolen_bases,
        caught_stealing,
        walks,
        strikeouts,
        batting_average,
        obp                 as on_base_percentage,
        slg                 as slugging_percentage,
        ops                 as on_base_plus_slugging,
        plate_appearances,
        total_bases,
        ground_into_dp      as ground_into_double_play,
        hit_by_pitch,
        sacrifice_bunts,
        sacrifice_flies,
        intentional_walks,
        loaded_at

    from source
)

select * from renamed

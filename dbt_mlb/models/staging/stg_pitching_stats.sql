with source as (
    select * from {{ source('raw_mlb', 'raw_pitching_stats') }}
),

renamed as (
    select
        id                  as pitching_stats_id,
        player_id,
        season,
        team_id,
        league_id,
        game_type,
        wins,
        losses,
        era,
        games,
        games_started,
        games_finished,
        complete_games,
        shutouts,
        saves,
        save_opportunities,
        holds,
        blown_saves,
        innings_pitched,
        hits_allowed,
        runs_allowed,
        earned_runs,
        home_runs_allowed,
        walks,
        strikeouts,
        hit_batsmen,
        whip,
        batting_average_against,
        wild_pitches,
        balks,
        strikeout_walk_ratio,
        strikeouts_per_9,
        walks_per_9,
        hits_per_9,
        loaded_at

    from source
)

select * from renamed

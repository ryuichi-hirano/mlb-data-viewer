with pitching as (
    select * from {{ ref('int_player_season_pitching') }}
),

players as (
    select
        player_id,
        full_name,
        position_name,
        pitch_hand
    from {{ ref('stg_players') }}
),

statcast as (
    select
        player_id,
        season,
        barrel_pct       as barrel_pct_against,
        hard_hit_pct     as hard_hit_pct_against,
        avg_exit_velocity as avg_exit_velocity_against,
        avg_expected_woba as xwoba_against
    from {{ ref('int_statcast_metrics') }}
    where player_role = 'pitcher'
)

select
    pit.player_id,
    pit.season,
    p.full_name,
    p.position_name,
    p.pitch_hand,
    pit.wins,
    pit.losses,
    case
        when (pit.wins + pit.losses) > 0
        then round(pit.wins::numeric / (pit.wins + pit.losses), 3)
    end as win_pct,
    pit.games,
    pit.games_started,
    pit.games_finished,
    pit.complete_games,
    pit.shutouts,
    pit.saves,
    pit.save_opportunities,
    pit.holds,
    pit.blown_saves,
    pit.innings_pitched,
    pit.hits_allowed,
    pit.runs_allowed,
    pit.earned_runs,
    pit.home_runs_allowed,
    pit.walks,
    pit.strikeouts,
    pit.hit_batsmen,
    pit.wild_pitches,
    pit.era,
    pit.whip,
    pit.fip,
    pit.strikeout_walk_ratio,
    pit.strikeouts_per_9,
    pit.walks_per_9,
    pit.hits_per_9,
    pit.batting_average_against,
    -- Derived: K% and BB% approximation (per batter faced estimate)
    case
        when pit.innings_pitched > 0
        then round(
            pit.strikeouts::numeric
            / (pit.innings_pitched * 3 + pit.hits_allowed + pit.walks + pit.hit_batsmen),
            3
        )
    end as strikeout_pct,
    case
        when pit.innings_pitched > 0
        then round(
            pit.walks::numeric
            / (pit.innings_pitched * 3 + pit.hits_allowed + pit.walks + pit.hit_batsmen),
            3
        )
    end as walk_pct,
    -- ERA- and FIP- would require league average; omitted for simplicity
    -- Statcast metrics against
    sc.barrel_pct_against,
    sc.hard_hit_pct_against,
    sc.avg_exit_velocity_against,
    sc.xwoba_against
from pitching pit
inner join players p on pit.player_id = p.player_id
left join statcast sc on pit.player_id = sc.player_id and pit.season = sc.season

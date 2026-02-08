with batting as (
    select * from {{ ref('int_player_season_batting') }}
),

players as (
    select
        player_id,
        full_name,
        position_name,
        position_type,
        bat_side
    from {{ ref('stg_players') }}
),

statcast as (
    select
        player_id,
        season,
        barrel_pct,
        hard_hit_pct,
        avg_exit_velocity,
        avg_launch_angle,
        max_exit_velocity,
        avg_expected_batting_avg,
        avg_expected_woba
    from {{ ref('int_statcast_metrics') }}
    where player_role = 'batter'
)

select
    b.player_id,
    b.season,
    p.full_name,
    p.position_name,
    p.position_type,
    p.bat_side,
    b.games_played,
    b.plate_appearances,
    b.at_bats,
    b.runs,
    b.hits,
    b.doubles,
    b.triples,
    b.home_runs,
    b.singles,
    b.rbi,
    b.stolen_bases,
    b.caught_stealing,
    b.walks,
    b.strikeouts,
    b.hit_by_pitch,
    b.sacrifice_flies,
    b.total_bases,
    b.ground_into_double_play,
    b.batting_average,
    b.on_base_percentage,
    b.slugging_percentage,
    b.on_base_plus_slugging,
    b.woba,
    -- Statcast metrics
    sc.barrel_pct,
    sc.hard_hit_pct,
    sc.avg_exit_velocity,
    sc.avg_launch_angle,
    sc.max_exit_velocity,
    sc.avg_expected_batting_avg  as xba,
    sc.avg_expected_woba         as xwoba,
    -- Derived: ISO (Isolated Power)
    case
        when b.at_bats > 0
        then round(b.slugging_percentage - b.batting_average, 3)
    end as iso,
    -- Derived: BB% and K%
    case
        when b.plate_appearances > 0
        then round(b.walks::numeric / b.plate_appearances, 3)
    end as walk_pct,
    case
        when b.plate_appearances > 0
        then round(b.strikeouts::numeric / b.plate_appearances, 3)
    end as strikeout_pct,
    -- Derived: BABIP
    case
        when (b.at_bats - b.strikeouts - b.home_runs + b.sacrifice_flies) > 0
        then round(
            (b.hits - b.home_runs)::numeric
            / (b.at_bats - b.strikeouts - b.home_runs + b.sacrifice_flies),
            3
        )
    end as babip
from batting b
inner join players p on b.player_id = p.player_id
left join statcast sc on b.player_id = sc.player_id and b.season = sc.season

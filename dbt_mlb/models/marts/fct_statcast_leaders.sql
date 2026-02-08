with statcast_batters as (
    select
        sm.player_id,
        sm.season,
        sm.player_role,
        p.full_name,
        p.position_name,
        sm.total_batted_balls,
        sm.barrels,
        sm.barrel_pct,
        sm.hard_hits,
        sm.hard_hit_pct,
        sm.avg_exit_velocity,
        sm.avg_launch_angle,
        sm.max_exit_velocity,
        sm.avg_expected_batting_avg  as xba,
        sm.avg_expected_woba         as xwoba,
        -- Leaderboard rankings (batter perspective)
        rank() over (partition by sm.season order by sm.avg_exit_velocity desc nulls last) as exit_velo_rank,
        rank() over (partition by sm.season order by sm.barrel_pct desc nulls last) as barrel_pct_rank,
        rank() over (partition by sm.season order by sm.hard_hit_pct desc nulls last) as hard_hit_pct_rank,
        rank() over (partition by sm.season order by sm.avg_expected_woba desc nulls last) as xwoba_rank
    from {{ ref('int_statcast_metrics') }} sm
    inner join {{ ref('stg_players') }} p on sm.player_id = p.player_id
    where sm.player_role = 'batter'
      and sm.total_batted_balls >= 50
),

statcast_pitchers as (
    select
        sm.player_id,
        sm.season,
        sm.player_role,
        p.full_name,
        p.position_name,
        sm.total_batted_balls,
        sm.barrels,
        sm.barrel_pct,
        sm.hard_hits,
        sm.hard_hit_pct,
        sm.avg_exit_velocity,
        sm.avg_launch_angle,
        sm.max_exit_velocity,
        sm.avg_expected_batting_avg  as xba,
        sm.avg_expected_woba         as xwoba,
        -- Leaderboard rankings (pitcher perspective - lower is better)
        rank() over (partition by sm.season order by sm.avg_exit_velocity asc nulls last) as exit_velo_rank,
        rank() over (partition by sm.season order by sm.barrel_pct asc nulls last) as barrel_pct_rank,
        rank() over (partition by sm.season order by sm.hard_hit_pct asc nulls last) as hard_hit_pct_rank,
        rank() over (partition by sm.season order by sm.avg_expected_woba asc nulls last) as xwoba_rank
    from {{ ref('int_statcast_metrics') }} sm
    inner join {{ ref('stg_players') }} p on sm.player_id = p.player_id
    where sm.player_role = 'pitcher'
      and sm.total_batted_balls >= 50
),

combined as (
    select * from statcast_batters
    union all
    select * from statcast_pitchers
)

select * from combined

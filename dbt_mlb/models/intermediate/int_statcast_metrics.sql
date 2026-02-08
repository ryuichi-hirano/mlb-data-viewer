with statcast as (
    select * from {{ ref('stg_statcast') }}
    where play_result is not null
),

batter_metrics as (
    select
        batter_id                   as player_id,
        season,
        'batter'                    as player_role,
        count(*)                    as total_batted_balls,

        -- Barrel: exit_velocity >= 98 AND launch_angle BETWEEN 26 AND 30
        sum(case
            when exit_velocity >= 98 and launch_angle between 26 and 30
            then 1 else 0
        end)                        as barrels,
        case
            when count(case when exit_velocity is not null then 1 end) > 0
            then round(
                sum(case
                    when exit_velocity >= 98 and launch_angle between 26 and 30
                    then 1 else 0
                end)::numeric
                / count(case when exit_velocity is not null then 1 end),
                3
            )
        end                         as barrel_pct,

        -- Hard Hit: exit_velocity >= 95
        sum(case
            when exit_velocity >= 95
            then 1 else 0
        end)                        as hard_hits,
        case
            when count(case when exit_velocity is not null then 1 end) > 0
            then round(
                sum(case
                    when exit_velocity >= 95
                    then 1 else 0
                end)::numeric
                / count(case when exit_velocity is not null then 1 end),
                3
            )
        end                         as hard_hit_pct,

        -- Average exit velocity and launch angle
        round(avg(exit_velocity)::numeric, 1) as avg_exit_velocity,
        round(avg(launch_angle)::numeric, 1)  as avg_launch_angle,

        -- Max exit velocity
        max(exit_velocity)                    as max_exit_velocity,

        -- Expected stats averages
        round(avg(expected_batting_avg)::numeric, 3) as avg_expected_batting_avg,
        round(avg(expected_woba)::numeric, 3)        as avg_expected_woba

    from statcast
    where exit_velocity is not null
    group by batter_id, season
),

pitcher_metrics as (
    select
        pitcher_id                  as player_id,
        season,
        'pitcher'                   as player_role,
        count(*)                    as total_batted_balls,

        -- Barrel: exit_velocity >= 98 AND launch_angle BETWEEN 26 AND 30
        sum(case
            when exit_velocity >= 98 and launch_angle between 26 and 30
            then 1 else 0
        end)                        as barrels,
        case
            when count(case when exit_velocity is not null then 1 end) > 0
            then round(
                sum(case
                    when exit_velocity >= 98 and launch_angle between 26 and 30
                    then 1 else 0
                end)::numeric
                / count(case when exit_velocity is not null then 1 end),
                3
            )
        end                         as barrel_pct,

        -- Hard Hit: exit_velocity >= 95
        sum(case
            when exit_velocity >= 95
            then 1 else 0
        end)                        as hard_hits,
        case
            when count(case when exit_velocity is not null then 1 end) > 0
            then round(
                sum(case
                    when exit_velocity >= 95
                    then 1 else 0
                end)::numeric
                / count(case when exit_velocity is not null then 1 end),
                3
            )
        end                         as hard_hit_pct,

        -- Average exit velocity and launch angle
        round(avg(exit_velocity)::numeric, 1) as avg_exit_velocity,
        round(avg(launch_angle)::numeric, 1)  as avg_launch_angle,

        -- Max exit velocity
        max(exit_velocity)                    as max_exit_velocity,

        -- Expected stats averages (from batter's perspective, allowed by pitcher)
        round(avg(expected_batting_avg)::numeric, 3) as avg_expected_batting_avg,
        round(avg(expected_woba)::numeric, 3)        as avg_expected_woba

    from statcast
    where exit_velocity is not null
    group by pitcher_id, season
),

combined as (
    select * from batter_metrics
    union all
    select * from pitcher_metrics
)

select * from combined

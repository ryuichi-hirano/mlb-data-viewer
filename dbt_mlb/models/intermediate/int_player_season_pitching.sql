with pitching as (
    select * from {{ ref('stg_pitching_stats') }}
    where game_type = 'R'
),

aggregated as (
    select
        player_id,
        season,
        sum(wins)                   as wins,
        sum(losses)                 as losses,
        sum(games)                  as games,
        sum(games_started)          as games_started,
        sum(games_finished)         as games_finished,
        sum(complete_games)         as complete_games,
        sum(shutouts)               as shutouts,
        sum(saves)                  as saves,
        sum(save_opportunities)     as save_opportunities,
        sum(holds)                  as holds,
        sum(blown_saves)            as blown_saves,
        sum(innings_pitched)        as innings_pitched,
        sum(hits_allowed)           as hits_allowed,
        sum(runs_allowed)           as runs_allowed,
        sum(earned_runs)            as earned_runs,
        sum(home_runs_allowed)      as home_runs_allowed,
        sum(walks)                  as walks,
        sum(strikeouts)             as strikeouts,
        sum(hit_batsmen)            as hit_batsmen,
        sum(wild_pitches)           as wild_pitches,
        sum(balks)                  as balks,

        -- ERA (Earned Run Average)
        case
            when sum(innings_pitched) > 0
            then round(sum(earned_runs)::numeric * 9 / sum(innings_pitched), 2)
        end as era,

        -- WHIP (Walks + Hits per Innings Pitched)
        case
            when sum(innings_pitched) > 0
            then round(
                (sum(walks) + sum(hits_allowed))::numeric / sum(innings_pitched),
                2
            )
        end as whip,

        -- K/BB (Strikeout to Walk Ratio)
        case
            when sum(walks) > 0
            then round(sum(strikeouts)::numeric / sum(walks), 2)
        end as strikeout_walk_ratio,

        -- K/9 (Strikeouts per 9 innings)
        case
            when sum(innings_pitched) > 0
            then round(sum(strikeouts)::numeric * 9 / sum(innings_pitched), 2)
        end as strikeouts_per_9,

        -- BB/9 (Walks per 9 innings)
        case
            when sum(innings_pitched) > 0
            then round(sum(walks)::numeric * 9 / sum(innings_pitched), 2)
        end as walks_per_9,

        -- H/9 (Hits per 9 innings)
        case
            when sum(innings_pitched) > 0
            then round(sum(hits_allowed)::numeric * 9 / sum(innings_pitched), 2)
        end as hits_per_9,

        -- BAA (Batting Average Against)
        -- Approximation: hits_allowed / (innings_pitched * 3 + hits_allowed)
        -- Using a simplified approach as we don't have batters faced directly
        case
            when sum(innings_pitched) > 0
            then round(
                sum(hits_allowed)::numeric
                / (sum(innings_pitched) * 3 + sum(hits_allowed)),
                3
            )
        end as batting_average_against,

        -- FIP (Fielding Independent Pitching)
        case
            when sum(innings_pitched) > 0
            then round(
                (
                    (13.0 * sum(home_runs_allowed) + 3.0 * sum(walks) - 2.0 * sum(strikeouts))
                    / sum(innings_pitched)
                ) + 3.20,
                2
            )
        end as fip

    from pitching
    group by player_id, season
)

select * from aggregated

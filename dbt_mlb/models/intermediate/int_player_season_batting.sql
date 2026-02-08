with batting as (
    select * from {{ ref('stg_batting_stats') }}
    where game_type = 'R'
),

aggregated as (
    select
        player_id,
        season,
        sum(games_played)           as games_played,
        sum(plate_appearances)      as plate_appearances,
        sum(at_bats)                as at_bats,
        sum(runs)                   as runs,
        sum(hits)                   as hits,
        sum(doubles)                as doubles,
        sum(triples)                as triples,
        sum(home_runs)              as home_runs,
        sum(hits) - sum(doubles) - sum(triples) - sum(home_runs) as singles,
        sum(rbi)                    as rbi,
        sum(stolen_bases)           as stolen_bases,
        sum(caught_stealing)        as caught_stealing,
        sum(walks)                  as walks,
        sum(strikeouts)             as strikeouts,
        sum(hit_by_pitch)           as hit_by_pitch,
        sum(sacrifice_bunts)        as sacrifice_bunts,
        sum(sacrifice_flies)        as sacrifice_flies,
        sum(intentional_walks)      as intentional_walks,
        sum(total_bases)            as total_bases,
        sum(ground_into_double_play) as ground_into_double_play,

        -- Batting Average
        case
            when sum(at_bats) > 0
            then round(sum(hits)::numeric / sum(at_bats), 3)
        end as batting_average,

        -- On-Base Percentage
        case
            when (sum(at_bats) + sum(walks) + sum(hit_by_pitch) + sum(sacrifice_flies)) > 0
            then round(
                (sum(hits) + sum(walks) + sum(hit_by_pitch))::numeric
                / (sum(at_bats) + sum(walks) + sum(hit_by_pitch) + sum(sacrifice_flies)),
                3
            )
        end as on_base_percentage,

        -- Slugging Percentage
        case
            when sum(at_bats) > 0
            then round(sum(total_bases)::numeric / sum(at_bats), 3)
        end as slugging_percentage,

        -- OPS
        case
            when sum(at_bats) > 0
                and (sum(at_bats) + sum(walks) + sum(hit_by_pitch) + sum(sacrifice_flies)) > 0
            then round(
                (sum(hits) + sum(walks) + sum(hit_by_pitch))::numeric
                / (sum(at_bats) + sum(walks) + sum(hit_by_pitch) + sum(sacrifice_flies))
                + sum(total_bases)::numeric / sum(at_bats),
                3
            )
        end as on_base_plus_slugging,

        -- wOBA (weighted On-Base Average)
        case
            when (sum(at_bats) + sum(walks) + sum(sacrifice_flies) + sum(hit_by_pitch)) > 0
            then round(
                (
                    0.69 * sum(walks)
                    + 0.72 * sum(hit_by_pitch)
                    + 0.888 * (sum(hits) - sum(doubles) - sum(triples) - sum(home_runs))
                    + 1.271 * sum(doubles)
                    + 1.616 * sum(triples)
                    + 2.101 * sum(home_runs)
                )::numeric
                / (sum(at_bats) + sum(walks) + sum(sacrifice_flies) + sum(hit_by_pitch)),
                3
            )
        end as woba

    from batting
    group by player_id, season
)

select * from aggregated

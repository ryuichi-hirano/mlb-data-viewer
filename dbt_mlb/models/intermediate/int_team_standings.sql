with game_results as (
    select * from {{ ref('int_game_results') }}
    where game_type = 'R'
),

teams as (
    select * from {{ ref('stg_teams') }}
),

team_records as (
    select
        gr.team_id,
        gr.season,
        count(*)                                    as games_played,
        sum(case when gr.is_win then 1 else 0 end)  as wins,
        sum(case when gr.is_loss then 1 else 0 end) as losses,
        sum(gr.runs_scored)                          as runs_scored,
        sum(gr.runs_allowed)                         as runs_allowed,
        case
            when count(*) > 0
            then round(
                sum(case when gr.is_win then 1 else 0 end)::numeric / count(*),
                3
            )
        end as win_pct,
        sum(case when gr.is_home and gr.is_win then 1 else 0 end) as home_wins,
        sum(case when gr.is_home and gr.is_loss then 1 else 0 end) as home_losses,
        sum(case when not gr.is_home and gr.is_win then 1 else 0 end) as away_wins,
        sum(case when not gr.is_home and gr.is_loss then 1 else 0 end) as away_losses
    from game_results gr
    group by gr.team_id, gr.season
),

with_team_info as (
    select
        tr.team_id,
        tr.season,
        t.team_full_name,
        t.team_abbreviation,
        t.league_name,
        t.division_name,
        tr.games_played,
        tr.wins,
        tr.losses,
        tr.win_pct,
        tr.runs_scored,
        tr.runs_allowed,
        tr.runs_scored - tr.runs_allowed as run_differential,
        tr.home_wins,
        tr.home_losses,
        tr.away_wins,
        tr.away_losses
    from team_records tr
    inner join teams t on tr.team_id = t.team_id
),

division_leaders as (
    select
        season,
        division_name,
        max(win_pct) as best_win_pct
    from with_team_info
    where division_name is not null
    group by season, division_name
),

final as (
    select
        wti.*,
        case
            when dl.best_win_pct is not null and wti.games_played > 0
            then round(
                (dl.best_win_pct * wti.games_played - wti.wins)::numeric / 1,
                1
            )
        end as games_behind
    from with_team_info wti
    left join division_leaders dl
        on wti.season = dl.season
        and wti.division_name = dl.division_name
)

select * from final

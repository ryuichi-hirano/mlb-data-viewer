with standings as (
    select * from {{ ref('int_team_standings') }}
),

team_batting as (
    select
        bs.team_id,
        bs.season,
        sum(bs.games_played)    as team_games_batted,
        sum(bs.plate_appearances) as team_plate_appearances,
        sum(bs.at_bats)         as team_at_bats,
        sum(bs.hits)            as team_hits,
        sum(bs.home_runs)       as team_home_runs,
        sum(bs.rbi)             as team_rbi,
        sum(bs.stolen_bases)    as team_stolen_bases,
        sum(bs.walks)           as team_walks,
        sum(bs.strikeouts)      as team_strikeouts,
        case
            when sum(bs.at_bats) > 0
            then round(sum(bs.hits)::numeric / sum(bs.at_bats), 3)
        end as team_batting_average,
        case
            when (sum(bs.at_bats) + sum(bs.walks) + sum(bs.hit_by_pitch) + sum(bs.sacrifice_flies)) > 0
            then round(
                (sum(bs.hits) + sum(bs.walks) + sum(bs.hit_by_pitch))::numeric
                / (sum(bs.at_bats) + sum(bs.walks) + sum(bs.hit_by_pitch) + sum(bs.sacrifice_flies)),
                3
            )
        end as team_obp,
        case
            when sum(bs.at_bats) > 0
            then round(sum(bs.total_bases)::numeric / sum(bs.at_bats), 3)
        end as team_slg
    from {{ ref('stg_batting_stats') }} bs
    where bs.game_type = 'R'
    group by bs.team_id, bs.season
),

team_pitching as (
    select
        ps.team_id,
        ps.season,
        sum(ps.innings_pitched) as team_innings_pitched,
        sum(ps.earned_runs)     as team_earned_runs,
        sum(ps.strikeouts)      as team_pitching_strikeouts,
        sum(ps.walks)           as team_pitching_walks,
        sum(ps.hits_allowed)    as team_hits_allowed,
        sum(ps.home_runs_allowed) as team_home_runs_allowed,
        sum(ps.saves)           as team_saves,
        case
            when sum(ps.innings_pitched) > 0
            then round(sum(ps.earned_runs)::numeric * 9 / sum(ps.innings_pitched), 2)
        end as team_era,
        case
            when sum(ps.innings_pitched) > 0
            then round(
                (sum(ps.walks) + sum(ps.hits_allowed))::numeric / sum(ps.innings_pitched),
                2
            )
        end as team_whip
    from {{ ref('stg_pitching_stats') }} ps
    where ps.game_type = 'R'
    group by ps.team_id, ps.season
)

select
    s.team_id,
    s.season,
    s.team_full_name,
    s.team_abbreviation,
    s.league_name,
    s.division_name,
    -- Record
    s.games_played,
    s.wins,
    s.losses,
    s.win_pct,
    s.games_behind,
    s.run_differential,
    s.home_wins,
    s.home_losses,
    s.away_wins,
    s.away_losses,
    s.runs_scored,
    s.runs_allowed,
    -- Team batting
    tb.team_batting_average,
    tb.team_obp,
    tb.team_slg,
    case
        when tb.team_obp is not null and tb.team_slg is not null
        then round(tb.team_obp + tb.team_slg, 3)
    end as team_ops,
    tb.team_home_runs,
    tb.team_rbi,
    tb.team_stolen_bases,
    tb.team_walks       as team_batting_walks,
    tb.team_strikeouts  as team_batting_strikeouts,
    -- Team pitching
    tp.team_era,
    tp.team_whip,
    tp.team_pitching_strikeouts,
    tp.team_pitching_walks,
    tp.team_saves,
    tp.team_home_runs_allowed,
    -- Pythagorean win expectation (RS^2 / (RS^2 + RA^2))
    case
        when s.runs_scored > 0 and s.runs_allowed > 0
        then round(
            power(s.runs_scored, 2)::numeric
            / (power(s.runs_scored, 2) + power(s.runs_allowed, 2)),
            3
        )
    end as pythagorean_win_pct,
    case
        when s.runs_scored > 0 and s.runs_allowed > 0 and s.games_played > 0
        then round(
            power(s.runs_scored, 2)::numeric
            / (power(s.runs_scored, 2) + power(s.runs_allowed, 2))
            * s.games_played,
            0
        )
    end as pythagorean_wins
from standings s
left join team_batting tb on s.team_id = tb.team_id and s.season = tb.season
left join team_pitching tp on s.team_id = tp.team_id and s.season = tp.season

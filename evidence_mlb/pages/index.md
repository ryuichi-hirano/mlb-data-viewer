---
title: MLB Analytics Dashboard
---

# MLB Analytics Overview

```sql total_games
SELECT
    COUNT(*) AS total_games,
    COUNT(DISTINCT season) AS seasons,
    SUM(home_score + away_score) AS total_runs,
    ROUND(AVG(home_score + away_score), 1) AS avg_runs_per_game,
    SUM(CASE WHEN is_extra_innings THEN 1 ELSE 0 END) AS extra_inning_games
FROM mlb.fct_game_summary
WHERE game_type = 'R'
```

```sql total_hr
SELECT COALESCE(SUM(home_runs), 0) AS total_home_runs
FROM mlb.fct_batting_performance
```

<BigValue
    data={total_games}
    value=total_games
    title="Total Games"
/>

<BigValue
    data={total_games}
    value=seasons
    title="Seasons"
/>

<BigValue
    data={total_hr}
    value=total_home_runs
    title="Total Home Runs"
/>

<BigValue
    data={total_games}
    value=avg_runs_per_game
    title="Avg Runs/Game"
/>

<BigValue
    data={total_games}
    value=extra_inning_games
    title="Extra Inning Games"
/>

## Team Win Percentage - Top 10

```sql top_teams
SELECT
    team_abbreviation,
    team_full_name,
    wins,
    losses,
    win_pct,
    run_differential,
    season
FROM mlb.fct_team_season_summary
ORDER BY win_pct DESC
LIMIT 10
```

<BarChart
    data={top_teams}
    x=team_abbreviation
    y=win_pct
    series=season
    title="Top 10 Teams by Win Percentage"
    yAxisTitle="Win %"
/>

## Recent Games

```sql recent_games
SELECT
    game_date,
    away_team_name || ' @ ' || home_team_name AS matchup,
    away_score || ' - ' || home_score AS score,
    CASE WHEN winner = 'home' THEN home_team_name ELSE away_team_name END AS winning_team,
    winning_pitcher_name,
    losing_pitcher_name,
    save_pitcher_name,
    CASE WHEN is_extra_innings THEN 'Yes' ELSE 'No' END AS extras
FROM mlb.fct_game_summary
WHERE game_type = 'R'
ORDER BY game_date DESC
LIMIT 20
```

<DataTable
    data={recent_games}
    rows=20
/>

## Run Differential vs Win Percentage

```sql team_scatter
SELECT
    team_abbreviation,
    team_full_name,
    win_pct,
    run_differential,
    division_name,
    season
FROM mlb.fct_team_season_summary
```

<ScatterPlot
    data={team_scatter}
    x=run_differential
    y=win_pct
    series=division_name
    title="Run Differential vs Win %"
    xAxisTitle="Run Differential"
    yAxisTitle="Win %"
    pointSize=8
/>

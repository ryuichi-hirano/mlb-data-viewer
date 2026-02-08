---
title: Team Standings
---

# Team Standings

```sql seasons
SELECT DISTINCT season FROM mlb.fct_team_season_summary ORDER BY season DESC
```

<Dropdown name=season_filter data={seasons} value=season defaultValue={seasons[0].season} title="Season" />

```sql standings
SELECT
    team_id,
    team_full_name,
    team_abbreviation,
    league_name,
    division_name,
    wins,
    losses,
    win_pct,
    games_behind,
    run_differential,
    runs_scored,
    runs_allowed,
    home_wins,
    home_losses,
    away_wins,
    away_losses,
    team_batting_average,
    team_ops,
    team_era,
    team_whip,
    team_home_runs,
    team_stolen_bases,
    team_pitching_strikeouts,
    team_saves,
    pythagorean_win_pct,
    pythagorean_wins,
    season
FROM mlb.fct_team_season_summary
WHERE season = '${inputs.season_filter.value}'
ORDER BY division_name, win_pct DESC
```

## American League

### AL East

```sql al_east
SELECT * FROM ${standings} WHERE division_name = 'American League East'
```

<DataTable data={al_east} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

### AL Central

```sql al_central
SELECT * FROM ${standings} WHERE division_name = 'American League Central'
```

<DataTable data={al_central} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

### AL West

```sql al_west
SELECT * FROM ${standings} WHERE division_name = 'American League West'
```

<DataTable data={al_west} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

## National League

### NL East

```sql nl_east
SELECT * FROM ${standings} WHERE division_name = 'National League East'
```

<DataTable data={nl_east} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

### NL Central

```sql nl_central
SELECT * FROM ${standings} WHERE division_name = 'National League Central'
```

<DataTable data={nl_central} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

### NL West

```sql nl_west
SELECT * FROM ${standings} WHERE division_name = 'National League West'
```

<DataTable data={nl_west} rows=5>
    <Column id=team_full_name title="Team" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=win_pct title="PCT" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=games_behind title="GB" fmt="num1" />
    <Column id=run_differential title="RD" contentType=colorscale scaleColor=green />
    <Column id=home_wins title="HW" />
    <Column id=home_losses title="HL" />
    <Column id=away_wins title="AW" />
    <Column id=away_losses title="AL" />
    <Column id=pythagorean_wins title="pyW" />
</DataTable>

## Team Offensive & Pitching Comparison

```sql team_comparison
SELECT
    team_abbreviation,
    team_full_name,
    team_ops,
    team_era,
    team_batting_average,
    team_whip,
    team_home_runs,
    team_stolen_bases,
    team_pitching_strikeouts,
    win_pct,
    division_name
FROM ${standings}
ORDER BY win_pct DESC
```

### Team OPS

<BarChart
    data={team_comparison}
    x=team_abbreviation
    y=team_ops
    title="Team OPS"
    yAxisTitle="OPS"
    swapXY=true
    sort=false
/>

### Team ERA

<BarChart
    data={team_comparison}
    x=team_abbreviation
    y=team_era
    title="Team ERA (sorted by Win%)"
    yAxisTitle="ERA"
    swapXY=true
    sort=false
/>

## Pythagorean Wins vs Actual Wins

```sql pyth_comparison
SELECT
    team_abbreviation,
    team_full_name,
    wins AS actual_wins,
    pythagorean_wins,
    wins - pythagorean_wins AS luck_factor,
    division_name
FROM ${standings}
ORDER BY wins - pythagorean_wins DESC
```

<DataTable data={pyth_comparison} rows=30>
    <Column id=team_full_name title="Team" />
    <Column id=actual_wins title="Actual W" />
    <Column id=pythagorean_wins title="Expected W" />
    <Column id=luck_factor title="Luck Factor" fmt="num0" contentType=colorscale scaleColor=green />
    <Column id=division_name title="Division" />
</DataTable>

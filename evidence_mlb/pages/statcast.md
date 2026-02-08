---
title: Statcast Insights
---

# Statcast Insights

```sql seasons
SELECT DISTINCT season FROM mlb.fct_statcast_leaders ORDER BY season DESC
```

<Dropdown name=season_filter data={seasons} value=season defaultValue={seasons[0].season} title="Season" />

<Dropdown name=role_filter title="Player Role">
    <DropdownOption value="batter" valueLabel="Batters" />
    <DropdownOption value="pitcher" valueLabel="Pitchers" />
</Dropdown>

```sql statcast_data
SELECT
    sl.player_id,
    sl.full_name,
    sl.position_name,
    sl.player_role,
    sl.total_batted_balls,
    sl.barrel_pct,
    sl.hard_hit_pct,
    sl.avg_exit_velocity,
    sl.max_exit_velocity,
    sl.xba,
    sl.xwoba,
    sl.exit_velo_rank,
    sl.barrel_pct_rank,
    sl.hard_hit_pct_rank,
    sl.xwoba_rank,
    p.current_team_name
FROM mlb.fct_statcast_leaders sl
LEFT JOIN mlb.dim_players p ON sl.player_id = p.player_id
WHERE sl.season = '${inputs.season_filter.value}'
    AND sl.player_role = '${inputs.role_filter.value}'
ORDER BY sl.avg_exit_velocity DESC
```

## Exit Velocity Leaders

```sql ev_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    avg_exit_velocity,
    max_exit_velocity,
    barrel_pct,
    hard_hit_pct,
    total_batted_balls,
    exit_velo_rank
FROM ${statcast_data}
ORDER BY avg_exit_velocity DESC
LIMIT 20
```

<BarChart
    data={ev_leaders}
    x=full_name
    y=avg_exit_velocity
    title="Average Exit Velocity Leaders"
    yAxisTitle="Avg EV (mph)"
    swapXY=true
    yMin=85
/>

<DataTable data={ev_leaders} rows=20>
    <Column id=exit_velo_rank title="Rank" />
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=avg_exit_velocity title="Avg EV" fmt="num1" contentType=colorscale scaleColor=red />
    <Column id=max_exit_velocity title="Max EV" fmt="num1" />
    <Column id=barrel_pct title="Barrel%" fmt="pct1" />
    <Column id=hard_hit_pct title="Hard Hit%" fmt="pct1" />
    <Column id=total_batted_balls title="BBE" />
</DataTable>

## Barrel Rate Leaders

```sql barrel_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    barrel_pct,
    hard_hit_pct,
    avg_exit_velocity,
    xwoba,
    total_batted_balls,
    barrel_pct_rank
FROM ${statcast_data}
ORDER BY barrel_pct DESC
LIMIT 20
```

<BarChart
    data={barrel_leaders}
    x=full_name
    y=barrel_pct
    title="Barrel Rate Leaders"
    yAxisTitle="Barrel %"
    swapXY=true
/>

<DataTable data={barrel_leaders} rows=20>
    <Column id=barrel_pct_rank title="Rank" />
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=barrel_pct title="Barrel%" fmt="pct1" contentType=colorscale scaleColor=red />
    <Column id=hard_hit_pct title="Hard Hit%" fmt="pct1" />
    <Column id=avg_exit_velocity title="Avg EV" fmt="num1" />
    <Column id=xwoba title="xwOBA" fmt="num3" />
    <Column id=total_batted_balls title="BBE" />
</DataTable>

## Hard Hit Rate Leaders

```sql hh_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    hard_hit_pct,
    barrel_pct,
    avg_exit_velocity,
    xwoba,
    total_batted_balls,
    hard_hit_pct_rank
FROM ${statcast_data}
ORDER BY hard_hit_pct DESC
LIMIT 20
```

<BarChart
    data={hh_leaders}
    x=full_name
    y=hard_hit_pct
    title="Hard Hit Rate Leaders"
    yAxisTitle="Hard Hit %"
    swapXY=true
/>

## xwOBA Leaders

```sql xwoba_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    xwoba,
    xba,
    barrel_pct,
    hard_hit_pct,
    avg_exit_velocity,
    total_batted_balls,
    xwoba_rank
FROM ${statcast_data}
WHERE xwoba IS NOT NULL
ORDER BY xwoba DESC
LIMIT 20
```

<DataTable data={xwoba_leaders} rows=20>
    <Column id=xwoba_rank title="Rank" />
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=xwoba title="xwOBA" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=xba title="xBA" fmt="num3" />
    <Column id=barrel_pct title="Barrel%" fmt="pct1" />
    <Column id=hard_hit_pct title="Hard Hit%" fmt="pct1" />
    <Column id=avg_exit_velocity title="Avg EV" fmt="num1" />
    <Column id=total_batted_balls title="BBE" />
</DataTable>

## Exit Velocity vs Barrel Rate

<ScatterPlot
    data={statcast_data}
    x=avg_exit_velocity
    y=barrel_pct
    pointSize=8
    title="Exit Velocity vs Barrel Rate"
    xAxisTitle="Avg Exit Velocity (mph)"
    yAxisTitle="Barrel %"
/>

## Hard Hit Rate vs xwOBA

<ScatterPlot
    data={statcast_data}
    x=hard_hit_pct
    y=xwoba
    pointSize=8
    title="Hard Hit Rate vs xwOBA"
    xAxisTitle="Hard Hit %"
    yAxisTitle="xwOBA"
/>

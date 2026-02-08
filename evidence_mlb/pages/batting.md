---
title: Batting Leaders
---

# Batting Leaders

```sql seasons
SELECT DISTINCT season FROM mlb.fct_batting_performance ORDER BY season DESC
```

```sql positions
SELECT DISTINCT position_name FROM mlb.fct_batting_performance WHERE position_name IS NOT NULL ORDER BY position_name
```

```sql teams
SELECT DISTINCT current_team_name
FROM mlb.dim_players
WHERE current_team_name IS NOT NULL
ORDER BY current_team_name
```

<Dropdown name=season_filter data={seasons} value=season defaultValue={seasons[0].season} title="Season" />

<Dropdown name=min_pa title="Min Plate Appearances">
    <DropdownOption value=0 valueLabel="No minimum" />
    <DropdownOption value=100 valueLabel="100 PA" />
    <DropdownOption value=200 valueLabel="200 PA" />
    <DropdownOption value=400 valueLabel="400 PA (Qualified)" />
    <DropdownOption value=502 valueLabel="502 PA (Full Season)" />
</Dropdown>

```sql batting_leaders
SELECT
    b.player_id,
    b.full_name,
    b.position_name,
    b.season,
    b.games_played,
    b.plate_appearances,
    b.batting_average,
    b.on_base_percentage,
    b.slugging_percentage,
    b.on_base_plus_slugging,
    b.woba,
    b.iso,
    b.babip,
    b.walk_pct,
    b.strikeout_pct,
    b.home_runs,
    b.rbi,
    b.stolen_bases,
    b.hits,
    b.runs,
    b.doubles,
    b.triples,
    b.xba,
    b.xwoba,
    b.barrel_pct,
    b.hard_hit_pct,
    b.avg_exit_velocity,
    p.current_team_name
FROM mlb.fct_batting_performance b
LEFT JOIN mlb.dim_players p ON b.player_id = p.player_id
WHERE b.season = '${inputs.season_filter.value}'
    AND b.plate_appearances >= '${inputs.min_pa.value}'
ORDER BY b.on_base_plus_slugging DESC
```

## OPS Leaders

<DataTable
    data={batting_leaders}
    rows=20
    search=true
>
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=games_played title="G" />
    <Column id=plate_appearances title="PA" />
    <Column id=batting_average title="AVG" fmt="num3" />
    <Column id=on_base_percentage title="OBP" fmt="num3" />
    <Column id=slugging_percentage title="SLG" fmt="num3" />
    <Column id=on_base_plus_slugging title="OPS" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=woba title="wOBA" fmt="num3" />
    <Column id=home_runs title="HR" />
    <Column id=rbi title="RBI" />
    <Column id=stolen_bases title="SB" />
</DataTable>

## Home Run Leaders

```sql hr_leaders
SELECT
    full_name,
    position_name,
    home_runs,
    rbi,
    on_base_plus_slugging,
    iso,
    barrel_pct,
    avg_exit_velocity
FROM ${batting_leaders}
WHERE home_runs > 0
ORDER BY home_runs DESC
LIMIT 20
```

<BarChart
    data={hr_leaders}
    x=full_name
    y=home_runs
    title="Home Run Leaders"
    yAxisTitle="Home Runs"
    swapXY=true
/>

## wOBA Rankings

```sql woba_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    plate_appearances,
    woba,
    on_base_plus_slugging,
    xwoba,
    batting_average,
    iso,
    walk_pct,
    strikeout_pct
FROM ${batting_leaders}
WHERE woba IS NOT NULL
ORDER BY woba DESC
LIMIT 20
```

<DataTable data={woba_leaders} rows=20>
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=plate_appearances title="PA" />
    <Column id=woba title="wOBA" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=xwoba title="xwOBA" fmt="num3" />
    <Column id=on_base_plus_slugging title="OPS" fmt="num3" />
    <Column id=batting_average title="AVG" fmt="num3" />
    <Column id=iso title="ISO" fmt="num3" />
    <Column id=walk_pct title="BB%" fmt="pct1" />
    <Column id=strikeout_pct title="K%" fmt="pct1" />
</DataTable>

## Stolen Base Leaders

```sql sb_leaders
SELECT
    full_name,
    stolen_bases,
    games_played,
    batting_average,
    on_base_percentage
FROM ${batting_leaders}
WHERE stolen_bases > 0
ORDER BY stolen_bases DESC
LIMIT 15
```

<BarChart
    data={sb_leaders}
    x=full_name
    y=stolen_bases
    title="Stolen Base Leaders"
    yAxisTitle="Stolen Bases"
    swapXY=true
/>

## Batting Average Leaders

```sql avg_leaders
SELECT
    full_name,
    position_name,
    current_team_name,
    plate_appearances,
    batting_average,
    on_base_percentage,
    slugging_percentage,
    babip,
    hits,
    doubles,
    triples
FROM ${batting_leaders}
WHERE batting_average IS NOT NULL
ORDER BY batting_average DESC
LIMIT 20
```

<DataTable data={avg_leaders} rows=20>
    <Column id=full_name title="Player" />
    <Column id=position_name title="Pos" />
    <Column id=current_team_name title="Team" />
    <Column id=plate_appearances title="PA" />
    <Column id=batting_average title="AVG" fmt="num3" contentType=colorscale scaleColor=blue />
    <Column id=on_base_percentage title="OBP" fmt="num3" />
    <Column id=slugging_percentage title="SLG" fmt="num3" />
    <Column id=babip title="BABIP" fmt="num3" />
    <Column id=hits title="H" />
    <Column id=doubles title="2B" />
    <Column id=triples title="3B" />
</DataTable>

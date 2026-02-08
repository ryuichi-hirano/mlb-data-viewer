---
title: Pitching Leaders
---

# Pitching Leaders

```sql seasons
SELECT DISTINCT season FROM mlb.fct_pitching_performance ORDER BY season DESC
```

```sql teams
SELECT DISTINCT current_team_name
FROM mlb.dim_players
WHERE current_team_name IS NOT NULL
ORDER BY current_team_name
```

<Dropdown name=season_filter data={seasons} value=season defaultValue={seasons[0].season} title="Season" />

<Dropdown name=min_ip title="Min Innings Pitched">
    <DropdownOption value=0 valueLabel="No minimum" />
    <DropdownOption value=30 valueLabel="30 IP" />
    <DropdownOption value=50 valueLabel="50 IP" />
    <DropdownOption value=100 valueLabel="100 IP" />
    <DropdownOption value=162 valueLabel="162 IP (Qualified)" />
</Dropdown>

<Dropdown name=role_filter title="Role">
    <DropdownOption value="all" valueLabel="All" />
    <DropdownOption value="starter" valueLabel="Starters" />
    <DropdownOption value="reliever" valueLabel="Relievers" />
</Dropdown>

```sql pitching_leaders
SELECT
    pp.player_id,
    pp.full_name,
    pp.position_name,
    pp.pitch_hand,
    pp.season,
    pp.wins,
    pp.losses,
    pp.win_pct,
    pp.era,
    pp.whip,
    pp.fip,
    pp.innings_pitched,
    pp.strikeouts,
    pp.walks,
    pp.strikeout_pct,
    pp.walk_pct,
    pp.strikeout_walk_ratio,
    pp.strikeouts_per_9,
    pp.walks_per_9,
    pp.hits_per_9,
    pp.batting_average_against,
    pp.games,
    pp.games_started,
    pp.saves,
    pp.holds,
    pp.barrel_pct_against,
    pp.hard_hit_pct_against,
    pp.avg_exit_velocity_against,
    pp.xwoba_against,
    p.current_team_name,
    CASE
        WHEN pp.games_started > pp.games * 0.5 THEN 'Starter'
        ELSE 'Reliever'
    END AS role
FROM mlb.fct_pitching_performance pp
LEFT JOIN mlb.dim_players p ON pp.player_id = p.player_id
WHERE pp.season = '${inputs.season_filter.value}'
    AND pp.innings_pitched >= '${inputs.min_ip.value}'
    AND (
        '${inputs.role_filter.value}' = 'all'
        OR ('${inputs.role_filter.value}' = 'starter' AND pp.games_started > pp.games * 0.5)
        OR ('${inputs.role_filter.value}' = 'reliever' AND pp.games_started <= pp.games * 0.5)
    )
ORDER BY pp.era ASC
```

## ERA Leaders

<DataTable
    data={pitching_leaders}
    rows=20
    search=true
>
    <Column id=full_name title="Player" />
    <Column id=current_team_name title="Team" />
    <Column id=role title="Role" />
    <Column id=pitch_hand title="Hand" />
    <Column id=wins title="W" />
    <Column id=losses title="L" />
    <Column id=era title="ERA" fmt="num2" contentType=colorscale scaleColor=green />
    <Column id=whip title="WHIP" fmt="num2" />
    <Column id=fip title="FIP" fmt="num2" />
    <Column id=innings_pitched title="IP" fmt="num1" />
    <Column id=strikeouts title="K" />
    <Column id=walks title="BB" />
    <Column id=saves title="SV" />
</DataTable>

## Strikeout Leaders

```sql k_leaders
SELECT
    full_name,
    role,
    strikeouts,
    innings_pitched,
    strikeouts_per_9,
    strikeout_pct,
    era
FROM ${pitching_leaders}
ORDER BY strikeouts DESC
LIMIT 20
```

<BarChart
    data={k_leaders}
    x=full_name
    y=strikeouts
    title="Strikeout Leaders"
    yAxisTitle="Strikeouts"
    swapXY=true
/>

## FIP Leaders (Lower is Better)

```sql fip_leaders
SELECT
    full_name,
    current_team_name,
    role,
    fip,
    era,
    whip,
    innings_pitched,
    strikeouts,
    walks,
    strikeout_walk_ratio
FROM ${pitching_leaders}
WHERE fip IS NOT NULL
ORDER BY fip ASC
LIMIT 20
```

<DataTable data={fip_leaders} rows=20>
    <Column id=full_name title="Player" />
    <Column id=current_team_name title="Team" />
    <Column id=role title="Role" />
    <Column id=fip title="FIP" fmt="num2" contentType=colorscale scaleColor=green />
    <Column id=era title="ERA" fmt="num2" />
    <Column id=whip title="WHIP" fmt="num2" />
    <Column id=innings_pitched title="IP" fmt="num1" />
    <Column id=strikeouts title="K" />
    <Column id=walks title="BB" />
    <Column id=strikeout_walk_ratio title="K/BB" fmt="num2" />
</DataTable>

## WHIP Leaders (Lower is Better)

```sql whip_leaders
SELECT
    full_name,
    current_team_name,
    role,
    whip,
    era,
    fip,
    innings_pitched,
    hits_per_9,
    walks_per_9
FROM ${pitching_leaders}
WHERE whip IS NOT NULL
ORDER BY whip ASC
LIMIT 20
```

<BarChart
    data={whip_leaders}
    x=full_name
    y=whip
    title="WHIP Leaders (Lower is Better)"
    yAxisTitle="WHIP"
    swapXY=true
/>

## Saves Leaders

```sql save_leaders
SELECT
    full_name,
    current_team_name,
    saves,
    holds,
    era,
    whip,
    innings_pitched,
    strikeouts
FROM ${pitching_leaders}
WHERE saves > 0
ORDER BY saves DESC
LIMIT 15
```

<DataTable data={save_leaders} rows=15>
    <Column id=full_name title="Player" />
    <Column id=current_team_name title="Team" />
    <Column id=saves title="SV" contentType=colorscale scaleColor=blue />
    <Column id=holds title="HLD" />
    <Column id=era title="ERA" fmt="num2" />
    <Column id=whip title="WHIP" fmt="num2" />
    <Column id=innings_pitched title="IP" fmt="num1" />
    <Column id=strikeouts title="K" />
</DataTable>

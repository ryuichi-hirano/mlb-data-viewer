---
title: Player Profile
---

```sql player_info
SELECT
    player_id,
    full_name,
    first_name,
    last_name,
    jersey_number,
    birth_date,
    birth_city,
    birth_country,
    height,
    weight,
    position_code,
    position_name,
    position_type,
    bat_side,
    pitch_hand,
    current_team_name,
    current_team_abbreviation,
    mlb_debut_date,
    CASE WHEN is_active THEN 'Active' ELSE 'Inactive' END AS status
FROM mlb.dim_players
WHERE player_id = '${params.player_id}'
```

{#if player_info.length > 0}

# {player_info[0].full_name}

<BigValue data={player_info} value=current_team_name title="Team" />
<BigValue data={player_info} value=position_name title="Position" />
<BigValue data={player_info} value=bat_side title="Bats" />
<BigValue data={player_info} value=pitch_hand title="Throws" />
<BigValue data={player_info} value=status title="Status" />

| | |
|---|---|
| **Jersey** | #{player_info[0].jersey_number} |
| **Born** | {player_info[0].birth_city}, {player_info[0].birth_country} |
| **Height/Weight** | {player_info[0].height} / {player_info[0].weight} lbs |
| **MLB Debut** | {player_info[0].mlb_debut_date} |

## Batting Stats

```sql batting_stats
SELECT
    season,
    games_played AS G,
    plate_appearances AS PA,
    at_bats AS AB,
    hits AS H,
    doubles AS "2B",
    triples AS "3B",
    home_runs AS HR,
    rbi AS RBI,
    runs AS R,
    stolen_bases AS SB,
    walks AS BB,
    strikeouts AS K,
    batting_average AS AVG,
    on_base_percentage AS OBP,
    slugging_percentage AS SLG,
    on_base_plus_slugging AS OPS,
    woba,
    iso AS ISO,
    babip AS BABIP,
    walk_pct AS "BB_pct",
    strikeout_pct AS "K_pct",
    xba,
    xwoba,
    barrel_pct,
    hard_hit_pct,
    avg_exit_velocity
FROM mlb.fct_batting_performance
WHERE player_id = '${params.player_id}'
ORDER BY season DESC
```

{#if batting_stats.length > 0}

<DataTable data={batting_stats} rows=10>
    <Column id=season title="Year" />
    <Column id=G />
    <Column id=PA />
    <Column id=AB />
    <Column id=H />
    <Column id=2B />
    <Column id=3B />
    <Column id=HR />
    <Column id=RBI />
    <Column id=R />
    <Column id=SB />
    <Column id=BB />
    <Column id=K />
    <Column id=AVG fmt="num3" />
    <Column id=OBP fmt="num3" />
    <Column id=SLG fmt="num3" />
    <Column id=OPS fmt="num3" contentType=colorscale scaleColor=blue />
</DataTable>

### Advanced Batting Metrics

<DataTable data={batting_stats} rows=10>
    <Column id=season title="Year" />
    <Column id=woba title="wOBA" fmt="num3" />
    <Column id=ISO fmt="num3" />
    <Column id=BABIP fmt="num3" />
    <Column id=BB_pct title="BB%" fmt="pct1" />
    <Column id=K_pct title="K%" fmt="pct1" />
    <Column id=xba title="xBA" fmt="num3" />
    <Column id=xwoba title="xwOBA" fmt="num3" />
    <Column id=barrel_pct title="Barrel%" fmt="pct1" />
    <Column id=hard_hit_pct title="HardHit%" fmt="pct1" />
    <Column id=avg_exit_velocity title="Avg EV" fmt="num1" />
</DataTable>

### OPS Trend

<LineChart
    data={batting_stats}
    x=season
    y=OPS
    title="OPS by Season"
    yAxisTitle="OPS"
/>

{:else}

_No batting stats available for this player._

{/if}

## Pitching Stats

```sql pitching_stats
SELECT
    season,
    wins AS W,
    losses AS L,
    era AS ERA,
    games AS G,
    games_started AS GS,
    saves AS SV,
    holds AS HLD,
    innings_pitched AS IP,
    strikeouts AS K,
    walks AS BB,
    whip AS WHIP,
    fip AS FIP,
    strikeouts_per_9 AS "K_per_9",
    walks_per_9 AS "BB_per_9",
    hits_per_9 AS "H_per_9",
    strikeout_walk_ratio AS "K_BB",
    batting_average_against AS BAA,
    strikeout_pct AS "K_pct",
    walk_pct AS "BB_pct",
    barrel_pct_against,
    hard_hit_pct_against,
    avg_exit_velocity_against,
    xwoba_against
FROM mlb.fct_pitching_performance
WHERE player_id = '${params.player_id}'
ORDER BY season DESC
```

{#if pitching_stats.length > 0}

<DataTable data={pitching_stats} rows=10>
    <Column id=season title="Year" />
    <Column id=W />
    <Column id=L />
    <Column id=ERA fmt="num2" contentType=colorscale scaleColor=green />
    <Column id=G />
    <Column id=GS />
    <Column id=SV />
    <Column id=HLD />
    <Column id=IP fmt="num1" />
    <Column id=K />
    <Column id=BB />
    <Column id=WHIP fmt="num2" />
    <Column id=FIP fmt="num2" />
    <Column id=K_per_9 title="K/9" fmt="num1" />
    <Column id=BB_per_9 title="BB/9" fmt="num1" />
    <Column id=K_BB title="K/BB" fmt="num2" />
</DataTable>

### Statcast Against

<DataTable data={pitching_stats} rows=10>
    <Column id=season title="Year" />
    <Column id=barrel_pct_against title="Barrel% Against" fmt="pct1" />
    <Column id=hard_hit_pct_against title="HardHit% Against" fmt="pct1" />
    <Column id=avg_exit_velocity_against title="Avg EV Against" fmt="num1" />
    <Column id=xwoba_against title="xwOBA Against" fmt="num3" />
</DataTable>

### ERA Trend

<LineChart
    data={pitching_stats}
    x=season
    y=ERA
    title="ERA by Season"
    yAxisTitle="ERA"
/>

{:else}

_No pitching stats available for this player._

{/if}

## Statcast Profile

```sql statcast_profile
SELECT
    sl.season,
    sl.player_role,
    sl.total_batted_balls AS BBE,
    sl.barrel_pct,
    sl.hard_hit_pct,
    sl.avg_exit_velocity,
    sl.max_exit_velocity,
    sl.xba,
    sl.xwoba,
    sl.exit_velo_rank,
    sl.barrel_pct_rank,
    sl.hard_hit_pct_rank,
    sl.xwoba_rank
FROM mlb.fct_statcast_leaders sl
WHERE sl.player_id = '${params.player_id}'
ORDER BY sl.season DESC
```

{#if statcast_profile.length > 0}

<DataTable data={statcast_profile} rows=10>
    <Column id=season title="Year" />
    <Column id=player_role title="Role" />
    <Column id=BBE title="BBE" />
    <Column id=barrel_pct title="Barrel%" fmt="pct1" />
    <Column id=hard_hit_pct title="HardHit%" fmt="pct1" />
    <Column id=avg_exit_velocity title="Avg EV" fmt="num1" />
    <Column id=max_exit_velocity title="Max EV" fmt="num1" />
    <Column id=xba title="xBA" fmt="num3" />
    <Column id=xwoba title="xwOBA" fmt="num3" />
    <Column id=exit_velo_rank title="EV Rank" />
    <Column id=barrel_pct_rank title="Barrel Rank" />
    <Column id=xwoba_rank title="xwOBA Rank" />
</DataTable>

{:else}

_No Statcast data available for this player._

{/if}

{:else}

_Player not found._

{/if}

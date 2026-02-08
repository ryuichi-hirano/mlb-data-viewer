# MLB Data Pipeline - QA Report

> Generated: 2026-02-08
> Pipeline: MLB Stats API / Statcast → PostgreSQL → dbt → Evidence

---

## 1. Test Coverage Summary

### 1.1 dbt Schema Tests (YAML-defined)

Tests defined in `schema.yml` files across all dbt layers:

| Layer | File | Models | Test Types | Count |
|-------|------|--------|------------|-------|
| Sources | `staging/sources.yml` | 7 raw tables | unique, not_null on PKs | 14 |
| Staging | `staging/schema.yml` | 7 models | unique, not_null, relationships, accepted_values | ~40 |
| Intermediate | `intermediate/schema.yml` | 5 models | not_null, accepted_values | ~15 |
| Marts | `marts/schema.yml` | 7 models | unique, not_null, accepted_values, relationships | ~25 |

**Total YAML-defined tests: ~94**

### 1.2 dbt Singular Tests (Custom SQL)

Located in `dbt_mlb/tests/`:

| Test | Layer | Validates |
|------|-------|-----------|
| `assert_batting_avg_in_range` | Staging | Batting average ∈ [0, 1] |
| `assert_era_in_range` | Staging | ERA ≥ 0 |
| `assert_game_scores_non_negative` | Staging | Completed games have non-negative scores |
| `assert_ops_equals_obp_plus_slg` | Intermediate | OPS ≈ OBP + SLG (tolerance: 0.005) |
| `assert_win_loss_consistency` | Intermediate | Each game has exactly 1 winner, 1 loser |
| `assert_team_season_wins_losses_sum` | Intermediate | W + L = Games Played |
| `assert_statcast_speed_in_range` | Staging | Release speed [40–110], exit velocity [10–125] |
| `assert_pythagorean_wins_reasonable` | Marts | Pythagorean wins within 15 of actual |

**Total singular tests: 8**

### 1.3 E2E Pipeline Tests (pytest)

Located in `tests/test_e2e_pipeline.py`:

| Test Class | Tests | Description |
|-----------|-------|-------------|
| `TestRawLayer` | 12 | Source data existence, PKs, FK integrity |
| `TestStagingLayer` | 6 | Row count matching, value ranges, completeness |
| `TestIntermediateLayer` | 6 | Calculation correctness, aggregation integrity |
| `TestMartsLayer` | 9 | Dimension uniqueness, fact validity, value ranges |
| `TestE2ETraceability` | 8 | Cross-layer data flow, FK traceability |
| `TestDataQualityProfile` | 4 | NULL rate thresholds |

**Total E2E tests: 45**

---

## 2. Test Taxonomy

### 2.1 Data Existence
- All 7 raw tables must have data (minimum row thresholds)
- All downstream layers must be non-empty

### 2.2 Uniqueness
- All primary keys across all layers tested for uniqueness
- Dimension tables (dim_teams, dim_players) have unique, not-null PKs
- fct_game_summary has unique game_pk

### 2.3 Referential Integrity
- Staging: Players → Teams, Games → Teams, Batting/Pitching → Players/Teams
- Intermediate: Game results → Teams, Standings → Teams
- Marts: All fact tables → Dimension tables
- Cross-layer: Mart facts traceable back to staging sources

### 2.4 Value Range Validation
- Batting average: [0, 1]
- ERA: ≥ 0
- OPS: ≈ OBP + SLG
- Game scores: ≥ 0 for completed games
- Release speed: [40, 110] mph
- Exit velocity: [10, 125] mph
- Walk/strikeout percentages: [0, 1]
- FIP: [-5, 30]

### 2.5 Business Logic
- W + L = Games Played (standings)
- Each game produces exactly 1 winner and 1 loser
- Pythagorean expectation within 15 games of actual
- pitch_result_type ∈ {B, S, X}
- player_role ∈ {batter, pitcher}

### 2.6 Data Completeness (NULL Rate Thresholds)
- Batting average NULL rate < 20%
- ERA NULL rate < 20%
- Release speed NULL rate < 15%
- Launch speed NULL rate < 85% (only populated for batted balls)

---

## 3. Pipeline Flow & Test Points

```
┌──────────────┐     ┌───────────────┐     ┌───────────────────┐     ┌─────────────┐
│  MLB Stats   │     │   raw_mlb.*   │     │   staging.*       │     │intermediate │
│  API /       │────▶│  (7 tables)   │────▶│  (7 views)        │────▶│  (5 tables) │
│  Statcast    │     │               │     │                   │     │             │
└──────────────┘     └───────┬───────┘     └─────────┬─────────┘     └──────┬──────┘
                             │                       │                      │
                    Tests:   │              Tests:   │             Tests:   │
                    • PKs    │              • PKs    │             • OPS    │
                    • FKs    │              • FKs    │             • W+L    │
                    • Count  │              • Range  │             • Roles  │
                    • NULLs  │              • Types  │             • FIP    │
                             │                       │                      │
                             ▼                       ▼                      ▼
                    ┌─────────────────────────────────────────────────────────┐
                    │                                                         │
                    │    ┌──────────────┐         ┌───────────────────┐      │
                    │    │  marts.*     │         │  evidence_mlb/    │      │
                    │    │ (7 tables)   │────────▶│  (6 dashboard     │      │
                    │    │              │         │   pages)          │      │
                    │    └──────┬───────┘         └───────────────────┘      │
                    │           │                                             │
                    │  Tests:   │     E2E Traceability:                      │
                    │  • Unique │     • raw → stg → int → marts count match │
                    │  • FKs   │     • All fact FKs resolve to dimensions   │
                    │  • Range │     • No orphan records at any layer       │
                    │  • Pyth  │                                             │
                    └─────────────────────────────────────────────────────────┘
```

---

## 4. How to Run Tests

### 4.1 dbt Tests

```bash
cd dbt_mlb

# Run all dbt tests (schema + singular)
dbt test

# Run only schema tests
dbt test --select "source:*" "staging.*" "intermediate.*" "marts.*"

# Run only singular tests
dbt test --select "test_type:singular"

# Run tests for a specific model
dbt test --select stg_batting_stats
```

### 4.2 E2E Pipeline Tests

```bash
# Run full E2E test suite
python -m pytest tests/test_e2e_pipeline.py -v

# Run specific test class
python -m pytest tests/test_e2e_pipeline.py::TestRawLayer -v
python -m pytest tests/test_e2e_pipeline.py::TestE2ETraceability -v

# Run with short traceback
python -m pytest tests/test_e2e_pipeline.py -v --tb=short
```

### 4.3 Full Pipeline Test Sequence

```bash
# 1. Extract data
cd /home/yilee/mlb_data_viewer
python main.py

# 2. Run dbt transformations
cd dbt_mlb
dbt run

# 3. Run dbt tests
dbt test

# 4. Run E2E tests
cd ..
python -m pytest tests/test_e2e_pipeline.py -v
```

---

## 5. Evidence Dashboard Queries

The Evidence dashboard at `evidence_mlb/` queries the following marts tables:

| Dashboard Page | Mart Tables Queried |
|----------------|---------------------|
| `index.md` (Overview) | fct_game_summary, fct_team_season_summary |
| `batting.md` | fct_batting_performance, dim_players |
| `pitching.md` | fct_pitching_performance, dim_players |
| `standings.md` | fct_team_season_summary, dim_teams |
| `statcast.md` | fct_statcast_leaders, dim_players |
| `players/[player_id].md` | dim_players, fct_batting_performance, fct_pitching_performance |

All source queries are defined in `evidence_mlb/sources/mlb/*.sql` and connect to the same PostgreSQL database via `connection.yaml`.

---

## 6. Known Considerations

1. **Statcast data volume**: A full season contains ~700K-800K pitch records. The `extract_statcast.py` script processes data in configurable chunks (default: 5 days) with rate limiting.

2. **NULL rates in Statcast**: Launch speed/angle are only populated for batted ball events (~25-35% of pitches). High NULL rates for these fields are expected.

3. **Division name format**: The staging layer normalizes division names to short format (e.g., "AL East"). Raw data may use full names (e.g., "American League East").

4. **FIP constant**: The intermediate layer uses FIP constant of 3.20, which is a league-average approximation. Actual FIP constants vary slightly by season.

5. **wOBA weights**: Linear weights used for wOBA calculation are based on 2024 season averages. Weights vary slightly year-to-year.

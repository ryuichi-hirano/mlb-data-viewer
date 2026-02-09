# MLB Data Viewer

An end-to-end MLB analytics pipeline that extracts data from the MLB Stats API and Baseball Savant, transforms it through a dbt data warehouse, and serves interactive dashboards via Evidence.

## Architecture

```
MLB Stats API ──┐                         ┌── dim_players
Baseball Savant ─┤  Python ETL  ┌─────┐   │── dim_teams
                 ├─────────────▶│ Raw │   │── fct_batting_performance
                 │   (scripts/) │ PG  │──▶│── fct_pitching_performance    ──▶  Evidence
                 │              └─────┘   │── fct_game_summary                Dashboard
                 │                dbt     │── fct_statcast_leaders
                 │           (dbt_mlb/)   │── fct_team_season_summary
                 │  staging ▶ intermediate ▶ marts
```

**Data sources:**
- [MLB Stats API](https://statsapi.mlb.com) — Teams, players, games, schedules, batting/pitching season stats
- [Baseball Savant](https://baseballsavant.mlb.com) (via pybaseball) — Pitch-level Statcast data (exit velocity, launch angle, spin rate, etc.)

## Features

- **7 extraction scripts** covering teams, players, schedules, games, batting stats, pitching stats, and Statcast data
- **19 dbt models** across three layers (staging, intermediate, marts) with advanced metrics (wOBA, FIP, Pythagorean wins, barrel rate)
- **6-page Evidence dashboard** with interactive filters, leaderboards, and visualizations
- **~147 automated tests** (dbt schema tests, singular tests, E2E pipeline tests)

## Project Structure

```
mlb_data_viewer/
├── config.yml                  # Database & extraction settings
├── config.docker.yml           # Docker config (host: db)
├── docker-compose.yml          # Multi-container orchestration
├── .env.example                # Environment variable template
├── pyproject.toml              # Python dependencies (uv)
├── main.py                     # Entry point
│
├── docker/                     # Docker build contexts
│   ├── db/init.sql             # DB init (schema + seed data)
│   ├── extraction/Dockerfile   # Python extraction container
│   ├── dbt/Dockerfile          # dbt transformation container
│   └── evidence/Dockerfile     # Evidence dashboard container
│
├── db/
│   └── schema.sql              # PostgreSQL DDL (7 raw tables, indexes)
│
├── scripts/                    # Python extraction scripts
│   ├── utils.py                # DB connection, logging, retry decorator
│   ├── extract_teams.py        # → raw_mlb.raw_teams
│   ├── extract_players.py      # → raw_mlb.raw_players
│   ├── extract_schedule.py     # → raw_mlb.raw_schedule
│   ├── extract_games.py        # → raw_mlb.raw_games
│   ├── extract_batting_stats.py  # → raw_mlb.raw_batting_stats
│   ├── extract_pitching_stats.py # → raw_mlb.raw_pitching_stats
│   ├── extract_statcast.py     # → raw_mlb.raw_statcast (pybaseball)
│   └── run_extraction.py       # Orchestrator (--skip / --only flags)
│
├── dbt_mlb/                    # dbt project
│   ├── dbt_project.yml
│   ├── profiles.yml
│   ├── models/
│   │   ├── staging/            # 7 views  — clean & rename raw columns
│   │   ├── intermediate/       # 5 tables — business logic & aggregations
│   │   └── marts/              # 7 tables — analytics-ready dimensions & facts
│   └── tests/                  # 8 singular SQL tests
│
├── evidence_mlb/               # Evidence dashboard
│   ├── evidence.config.yaml
│   ├── sources/mlb/            # PostgreSQL connection
│   └── pages/                  # 6 dashboard pages
│
├── tests/
│   └── test_e2e_pipeline.py    # 45 E2E tests (6 test classes)
│
└── docs/
    ├── api_endpoints.md        # MLB API documentation
    └── qa_report.md            # QA test coverage report
```

## Quick Start (Docker)

The fastest way to get started is using Docker Compose, which sets up PostgreSQL, runs the data pipeline, and launches the dashboard automatically.

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2+)

### 1. Configure Environment

```bash
cp .env.example .env
```

Edit `.env` if needed (defaults work out of the box):

```env
POSTGRES_USER=mlb_user
POSTGRES_PASSWORD=mlb_password
POSTGRES_DB=mlb_data
EVIDENCE_PORT=3000
```

### 2. Start the Database and Dashboard

```bash
docker compose up -d
```

This starts:
- **db** — PostgreSQL 16 with schema auto-initialization
- **evidence** — Dashboard at [http://localhost:3000](http://localhost:3000)

### 3. Run the Data Pipeline

The extraction and dbt steps are one-shot jobs under the `pipeline` profile:

```bash
# Extract data from MLB Stats API (takes a while on first run)
docker compose --profile pipeline run --rm extraction

# Run dbt transformations (raw → staging → intermediate → marts)
docker compose --profile pipeline run --rm dbt
```

To skip Statcast data (which is the slowest step):

```bash
docker compose --profile pipeline run --rm extraction --skip statcast
```

### 4. Access the Dashboard

Open [http://localhost:3000](http://localhost:3000) in your browser. The dashboard reads from the marts tables populated by dbt.

### 5. Stop Services

```bash
# Stop all running services
docker compose down

# Stop and remove data volumes (full reset)
docker compose down -v
```

### Docker Troubleshooting

| Issue | Solution |
|---|---|
| Database connection refused | Wait for healthcheck: `docker compose ps` should show db as "healthy" |
| Extraction fails mid-run | Re-run with `docker compose --profile pipeline run --rm extraction` (upserts are idempotent) |
| Dashboard shows no data | Ensure extraction and dbt have completed: check logs with `docker compose logs dbt` |
| Port 5432 already in use | Change `POSTGRES_PORT` in `.env` or stop your local PostgreSQL |
| Port 3000 already in use | Change `EVIDENCE_PORT` in `.env` |

---

## Local Development (without Docker)

### Prerequisites

- Python 3.12+
- PostgreSQL 14+
- Node.js 18+ (for Evidence)
- [uv](https://docs.astral.sh/uv/) (Python package manager)

## Setup

### 1. Database

```bash
# Create database and schema
createdb mlb_data
psql mlb_data < db/schema.sql
```

### 2. Python Environment

```bash
uv sync
```

### 3. Configuration

Edit `config.yml` to match your PostgreSQL credentials:

```yaml
database:
  host: localhost
  port: 5432
  dbname: mlb_data
  user: your_user
  password: your_password
```

## Usage

### Extract Data

```bash
# Run all extraction steps (in dependency order)
python main.py

# Run specific steps only
python main.py --only teams players

# Skip specific steps
python main.py --skip statcast
```

Extraction order: `teams` → `players` → `schedule` → `games` → `batting_stats` → `pitching_stats` → `statcast`

### Run dbt Transformations

```bash
cd dbt_mlb

# Install dbt packages
dbt deps

# Run all models
dbt run

# Run tests
dbt test
```

### Launch Dashboard

```bash
cd evidence_mlb

# Set database credentials
export POSTGRES_USER=your_user
export POSTGRES_PASSWORD=your_password

# Install dependencies & start dev server
npm install
npm run dev
```

## dbt Models

### Staging (views)

| Model | Description |
|---|---|
| `stg_teams` | Team master data |
| `stg_players` | Player biographical data |
| `stg_games` | Game results |
| `stg_schedule` | Season schedule |
| `stg_batting_stats` | Season batting statistics |
| `stg_pitching_stats` | Season pitching statistics |
| `stg_statcast` | Pitch-level Statcast data |

### Intermediate (tables)

| Model | Description |
|---|---|
| `int_player_season_batting` | Player-season batting aggregation with wOBA |
| `int_player_season_pitching` | Player-season pitching aggregation with FIP |
| `int_game_results` | Unpivoted game results (one row per team per game) |
| `int_team_standings` | Team standings with win%, games behind |
| `int_statcast_metrics` | Statcast aggregations (barrel%, hard-hit%, avg EV) |

### Marts (tables)

| Model | Description |
|---|---|
| `dim_players` | Player dimension |
| `dim_teams` | Team dimension |
| `fct_batting_performance` | Batting facts: traditional + advanced (wOBA, ISO, BABIP) + Statcast (xBA, xwOBA, barrel%) |
| `fct_pitching_performance` | Pitching facts: traditional + FIP + Statcast-against metrics |
| `fct_game_summary` | Enriched game summary with pitcher names and derived fields |
| `fct_statcast_leaders` | Statcast leaderboard with rankings by EV, barrel%, hard-hit%, xwOBA |
| `fct_team_season_summary` | Team season summary with Pythagorean win expectation |

## Dashboard Pages

| Page | Description |
|---|---|
| **Overview** | KPI cards, team win% bar chart, recent games, run differential scatter plot |
| **Batting Leaders** | OPS, wOBA, HR, SB leaderboards with position/team filters |
| **Pitching Leaders** | ERA, FIP, WHIP, K leaderboards with starter/reliever filters |
| **Team Standings** | Division standings, team OPS/ERA comparisons, Pythagorean analysis |
| **Statcast Insights** | Exit velocity, barrel%, hard-hit% leaders with scatter plots |
| **Player Profile** | Individual player page with stats, Statcast metrics, trend charts |

## Testing

The project includes ~147 automated tests across three layers:

```bash
# dbt schema + singular tests (~102 tests)
cd dbt_mlb && dbt test

# E2E pipeline tests (45 tests)
cd .. && python -m pytest tests/test_e2e_pipeline.py -v
```

Test categories:
- **Schema tests** — uniqueness, not-null, accepted values, referential integrity
- **Singular tests** — batting average range, ERA validity, OPS consistency, Pythagorean reasonableness
- **E2E tests** — raw-to-marts data traceability, calculation accuracy, NULL rate thresholds

## License

This project is licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see the [LICENSE](LICENSE) file for details.

GPL-3.0 is required due to the [MLB-StatsAPI](https://github.com/toddrob99/MLB-StatsAPI) dependency (GPL-3.0 copyleft).

### Data Usage Restrictions

MLB data accessed through the MLB Stats API is restricted to **individual, non-commercial, non-bulk use** per [MLB Advanced Media's terms](http://gdx.mlb.com/components/copyright.txt). Commercial use requires prior written authorization from MLBAM.

See [NOTICE](NOTICE) for full third-party attribution.

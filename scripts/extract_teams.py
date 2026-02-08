import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_teams"
CONFLICT_COLS = ["team_id"]


@retry(max_retries=3, backoff_factor=2)
def fetch_teams(cfg):
    season = cfg["extraction"]["season"]
    sport_id = cfg["extraction"]["sport_id"]
    data = statsapi.get(
        "teams",
        {"sportId": sport_id, "season": season},
    )
    return data.get("teams", [])


def transform_team(t):
    return {
        "team_id": t["id"],
        "name": t["name"],
        "team_code": t.get("teamCode"),
        "abbreviation": t.get("abbreviation"),
        "team_name": t.get("teamName"),
        "location_name": t.get("locationName"),
        "league_id": t.get("league", {}).get("id"),
        "league_name": t.get("league", {}).get("name"),
        "division_id": t.get("division", {}).get("id"),
        "division_name": t.get("division", {}).get("name"),
        "venue_id": t.get("venue", {}).get("id"),
        "venue_name": t.get("venue", {}).get("name"),
        "sport_id": t.get("sport", {}).get("id", 1),
        "active": t.get("active", True),
        "first_year_of_play": t.get("firstYearOfPlay"),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting teams extraction")

    teams = fetch_teams(cfg)
    logger.info(f"Fetched {len(teams)} teams from API")

    rows = [transform_team(t) for t in teams]

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} teams into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

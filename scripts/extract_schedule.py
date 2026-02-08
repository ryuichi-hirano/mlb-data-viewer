import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_schedule"
CONFLICT_COLS = ["game_pk", "game_date"]


@retry(max_retries=3, backoff_factor=2)
def fetch_schedule(cfg):
    season = cfg["extraction"]["season"]
    game_types = cfg["extraction"]["game_types"]
    params = {
        "sportId": cfg["extraction"]["sport_id"],
        "season": season,
        "gameTypes": ",".join(game_types),
        "hydrate": "linescore",
    }
    data = statsapi.get("schedule", params)
    return data.get("dates", [])


def transform_schedule_game(g, game_date):
    teams = g.get("teams", {})
    home = teams.get("home", {})
    away = teams.get("away", {})
    return {
        "game_pk": g["gamePk"],
        "game_date": game_date,
        "game_type": g.get("gameType"),
        "season": int(g.get("season", 0)) if g.get("season") else None,
        "status_code": g.get("status", {}).get("statusCode"),
        "status_detail": g.get("status", {}).get("detailedState"),
        "home_team_id": home.get("team", {}).get("id"),
        "home_team_name": home.get("team", {}).get("name"),
        "away_team_id": away.get("team", {}).get("id"),
        "away_team_name": away.get("team", {}).get("name"),
        "venue_id": g.get("venue", {}).get("id"),
        "venue_name": g.get("venue", {}).get("name"),
        "game_datetime": g.get("gameDate"),
        "day_night": g.get("dayNight"),
        "series_description": g.get("seriesDescription"),
        "series_game_number": g.get("seriesGameNumber"),
        "games_in_series": g.get("gamesInSeries"),
        "double_header": g.get("doubleHeader"),
        "scheduled_innings": g.get("scheduledInnings", 9),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting schedule extraction")

    dates = fetch_schedule(cfg)
    logger.info(f"Fetched {len(dates)} dates from schedule API")

    rows = []
    for date_entry in dates:
        game_date = date_entry["date"]
        for g in date_entry.get("games", []):
            rows.append(transform_schedule_game(g, game_date))

    logger.info(f"Total schedule entries: {len(rows)}")

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} schedule entries into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

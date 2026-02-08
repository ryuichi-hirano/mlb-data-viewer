import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_games"
CONFLICT_COLS = ["game_pk"]


@retry(max_retries=3, backoff_factor=2)
def fetch_schedule_for_games(cfg):
    season = cfg["extraction"]["season"]
    game_types = cfg["extraction"]["game_types"]
    params = {
        "sportId": cfg["extraction"]["sport_id"],
        "season": season,
        "gameTypes": ",".join(game_types),
        "hydrate": "linescore,decisions",
    }
    data = statsapi.get("schedule", params)
    return data.get("dates", [])


@retry(max_retries=3, backoff_factor=2)
def fetch_boxscore(game_pk, cfg):
    data = statsapi.get("game", {"gamePk": game_pk})
    return data


def transform_game(g, game_date):
    teams = g.get("teams", {})
    home = teams.get("home", {})
    away = teams.get("away", {})
    linescore = g.get("linescore", {})
    decisions = g.get("decisions", {})

    innings_list = linescore.get("innings", [])
    innings_count = len(innings_list) if innings_list else g.get("scheduledInnings")

    return {
        "game_pk": g["gamePk"],
        "game_type": g.get("gameType"),
        "season": int(g.get("season", 0)) if g.get("season") else None,
        "game_date": game_date,
        "game_datetime": g.get("gameDate"),
        "status_code": g.get("status", {}).get("statusCode"),
        "status_detail": g.get("status", {}).get("detailedState"),
        "home_team_id": home.get("team", {}).get("id"),
        "away_team_id": away.get("team", {}).get("id"),
        "home_score": home.get("score"),
        "away_score": away.get("score"),
        "home_wins": home.get("leagueRecord", {}).get("wins"),
        "home_losses": home.get("leagueRecord", {}).get("losses"),
        "away_wins": away.get("leagueRecord", {}).get("wins"),
        "away_losses": away.get("leagueRecord", {}).get("losses"),
        "venue_id": g.get("venue", {}).get("id"),
        "venue_name": g.get("venue", {}).get("name"),
        "winning_pitcher_id": decisions.get("winner", {}).get("id"),
        "losing_pitcher_id": decisions.get("loser", {}).get("id"),
        "save_pitcher_id": decisions.get("save", {}).get("id"),
        "innings": innings_count,
        "day_night": g.get("dayNight"),
        "series_description": g.get("seriesDescription"),
        "series_game_number": g.get("seriesGameNumber"),
        "double_header": g.get("doubleHeader"),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting games extraction")

    dates = fetch_schedule_for_games(cfg)
    logger.info(f"Fetched {len(dates)} dates from schedule API")

    rows = []
    for date_entry in dates:
        game_date = date_entry["date"]
        for g in date_entry.get("games", []):
            status = g.get("status", {}).get("statusCode", "")
            if status in ("F", "FT", "FR", "FO"):  # Final statuses only
                rows.append(transform_game(g, game_date))

    logger.info(f"Total completed games: {len(rows)}")

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} games into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

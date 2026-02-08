import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_players"
CONFLICT_COLS = ["player_id"]


@retry(max_retries=3, backoff_factor=2)
def fetch_team_roster(team_id, season, cfg):
    data = statsapi.get(
        "team_roster",
        {"teamId": team_id, "season": season, "rosterType": "fullSeason"},
    )
    return data.get("roster", [])


@retry(max_retries=3, backoff_factor=2)
def fetch_player_detail(player_id, cfg):
    data = statsapi.get("person", {"personId": player_id})
    people = data.get("people", [])
    return people[0] if people else None


def transform_player(p, team_id=None):
    pos = p.get("primaryPosition", {})
    return {
        "player_id": p["id"],
        "full_name": p.get("fullName", ""),
        "first_name": p.get("firstName"),
        "last_name": p.get("lastName"),
        "primary_number": p.get("primaryNumber"),
        "birth_date": p.get("birthDate"),
        "birth_city": p.get("birthCity"),
        "birth_country": p.get("birthCountry"),
        "height": p.get("height"),
        "weight": p.get("weight"),
        "primary_position_code": pos.get("code"),
        "primary_position_name": pos.get("name"),
        "primary_position_type": pos.get("type"),
        "bat_side": p.get("batSide", {}).get("code"),
        "pitch_hand": p.get("pitchHand", {}).get("code"),
        "current_team_id": p.get("currentTeam", {}).get("id") or team_id,
        "mlb_debut_date": p.get("mlbDebutDate"),
        "active": p.get("active", True),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting players extraction")

    season = cfg["extraction"]["season"]

    # First get all teams
    teams_data = statsapi.get(
        "teams",
        {"sportId": cfg["extraction"]["sport_id"], "season": season},
    )
    teams = teams_data.get("teams", [])
    logger.info(f"Found {len(teams)} teams")

    all_rows = []
    seen_ids = set()

    for team in teams:
        team_id = team["id"]
        logger.info(f"Fetching roster for {team['name']} (ID: {team_id})")
        rate_limit(cfg)

        roster = fetch_team_roster(team_id, season, cfg)
        player_ids = [entry["person"]["id"] for entry in roster]
        logger.info(f"  Found {len(player_ids)} players on roster")

        for pid in player_ids:
            if pid in seen_ids:
                continue
            seen_ids.add(pid)
            rate_limit(cfg)
            detail = fetch_player_detail(pid, cfg)
            if detail:
                all_rows.append(transform_player(detail, team_id))

    logger.info(f"Fetched {len(all_rows)} unique players")

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, all_rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} players into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

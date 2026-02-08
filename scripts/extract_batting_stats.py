import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_batting_stats"
CONFLICT_COLS = ["player_id", "season", "team_id", "game_type"]


@retry(max_retries=3, backoff_factor=2)
def fetch_team_roster(team_id, season):
    data = statsapi.get(
        "team_roster",
        {"teamId": team_id, "season": season, "rosterType": "fullSeason"},
    )
    return data.get("roster", [])


@retry(max_retries=3, backoff_factor=2)
def fetch_player_hitting_stats(player_id, season, game_type="R"):
    data = statsapi.get(
        "person_stats",
        {
            "personId": player_id,
            "hydrate": f"stats(group=[hitting],type=[season],season={season},gameType={game_type})",
        },
    )
    people = data.get("people", [])
    if not people:
        return None
    stats_list = people[0].get("stats", [])
    for stat_group in stats_list:
        if stat_group.get("group", {}).get("displayName") == "hitting":
            splits = stat_group.get("splits", [])
            if splits:
                return splits
    return None


def safe_numeric(val, default=None):
    if val is None or val == "":
        return default
    try:
        return float(val)
    except (ValueError, TypeError):
        return default


def safe_int(val, default=None):
    if val is None or val == "":
        return default
    try:
        return int(val)
    except (ValueError, TypeError):
        return default


def transform_batting_stat(split, player_id, season, game_type):
    s = split.get("stat", {})
    team = split.get("team", {})
    league = split.get("league", {})
    return {
        "player_id": player_id,
        "season": season,
        "team_id": team.get("id"),
        "league_id": league.get("id"),
        "game_type": game_type,
        "games_played": safe_int(s.get("gamesPlayed")),
        "at_bats": safe_int(s.get("atBats")),
        "runs": safe_int(s.get("runs")),
        "hits": safe_int(s.get("hits")),
        "doubles": safe_int(s.get("doubles")),
        "triples": safe_int(s.get("triples")),
        "home_runs": safe_int(s.get("homeRuns")),
        "rbi": safe_int(s.get("rbi")),
        "stolen_bases": safe_int(s.get("stolenBases")),
        "caught_stealing": safe_int(s.get("caughtStealing")),
        "walks": safe_int(s.get("baseOnBalls")),
        "strikeouts": safe_int(s.get("strikeOuts")),
        "batting_average": safe_numeric(s.get("avg")),
        "obp": safe_numeric(s.get("obp")),
        "slg": safe_numeric(s.get("slg")),
        "ops": safe_numeric(s.get("ops")),
        "plate_appearances": safe_int(s.get("plateAppearances")),
        "total_bases": safe_int(s.get("totalBases")),
        "ground_into_dp": safe_int(s.get("groundIntoDoublePlay")),
        "hit_by_pitch": safe_int(s.get("hitByPitch")),
        "sacrifice_bunts": safe_int(s.get("sacBunts")),
        "sacrifice_flies": safe_int(s.get("sacFlies")),
        "intentional_walks": safe_int(s.get("intentionalWalks")),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting batting stats extraction")

    season = cfg["extraction"]["season"]
    game_types = cfg["extraction"]["game_types"]

    # Get all teams
    teams_data = statsapi.get(
        "teams",
        {"sportId": cfg["extraction"]["sport_id"], "season": season},
    )
    teams = teams_data.get("teams", [])
    logger.info(f"Found {len(teams)} teams")

    all_rows = []
    seen = set()

    for team in teams:
        team_id = team["id"]
        logger.info(f"Processing batting stats for {team['name']}")
        rate_limit(cfg)

        roster = fetch_team_roster(team_id, season)
        player_ids = [entry["person"]["id"] for entry in roster]

        for pid in player_ids:
            if pid in seen:
                continue
            seen.add(pid)

            for gt in game_types:
                rate_limit(cfg)
                splits = fetch_player_hitting_stats(pid, season, gt)
                if splits:
                    for split in splits:
                        row = transform_batting_stat(split, pid, season, gt)
                        if row["team_id"] is not None:
                            all_rows.append(row)

    logger.info(f"Total batting stat rows: {len(all_rows)}")

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, all_rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} batting stats into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

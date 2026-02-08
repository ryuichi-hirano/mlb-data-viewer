import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "MLB-StatsAPI"))

import statsapi
from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_pitching_stats"
CONFLICT_COLS = ["player_id", "season", "team_id", "game_type"]


@retry(max_retries=3, backoff_factor=2)
def fetch_team_roster(team_id, season):
    data = statsapi.get(
        "team_roster",
        {"teamId": team_id, "season": season, "rosterType": "fullSeason"},
    )
    return data.get("roster", [])


@retry(max_retries=3, backoff_factor=2)
def fetch_player_pitching_stats(player_id, season, game_type="R"):
    data = statsapi.get(
        "person_stats",
        {
            "personId": player_id,
            "hydrate": f"stats(group=[pitching],type=[season],season={season},gameType={game_type})",
        },
    )
    people = data.get("people", [])
    if not people:
        return None
    stats_list = people[0].get("stats", [])
    for stat_group in stats_list:
        if stat_group.get("group", {}).get("displayName") == "pitching":
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


def transform_pitching_stat(split, player_id, season, game_type):
    s = split.get("stat", {})
    team = split.get("team", {})
    league = split.get("league", {})

    ip_str = s.get("inningsPitched", "0")
    try:
        ip = float(ip_str)
    except (ValueError, TypeError):
        ip = None

    return {
        "player_id": player_id,
        "season": season,
        "team_id": team.get("id"),
        "league_id": league.get("id"),
        "game_type": game_type,
        "wins": safe_int(s.get("wins")),
        "losses": safe_int(s.get("losses")),
        "era": safe_numeric(s.get("era")),
        "games": safe_int(s.get("gamesPitched")),
        "games_started": safe_int(s.get("gamesStarted")),
        "games_finished": safe_int(s.get("gamesFinished")),
        "complete_games": safe_int(s.get("completeGames")),
        "shutouts": safe_int(s.get("shutouts")),
        "saves": safe_int(s.get("saves")),
        "save_opportunities": safe_int(s.get("saveOpportunities")),
        "holds": safe_int(s.get("holds")),
        "blown_saves": safe_int(s.get("blownSaves")),
        "innings_pitched": ip,
        "hits_allowed": safe_int(s.get("hits")),
        "runs_allowed": safe_int(s.get("runs")),
        "earned_runs": safe_int(s.get("earnedRuns")),
        "home_runs_allowed": safe_int(s.get("homeRuns")),
        "walks": safe_int(s.get("baseOnBalls")),
        "strikeouts": safe_int(s.get("strikeOuts")),
        "hit_batsmen": safe_int(s.get("hitBatsmen")),
        "whip": safe_numeric(s.get("whip")),
        "batting_average_against": safe_numeric(s.get("avg")),
        "wild_pitches": safe_int(s.get("wildPitches")),
        "balks": safe_int(s.get("balks")),
        "strikeout_walk_ratio": safe_numeric(s.get("strikeoutWalkRatio")),
        "strikeouts_per_9": safe_numeric(s.get("strikeoutsPer9Inn")),
        "walks_per_9": safe_numeric(s.get("walksPer9Inn")),
        "hits_per_9": safe_numeric(s.get("hitsPer9Inn")),
    }


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting pitching stats extraction")

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
        logger.info(f"Processing pitching stats for {team['name']}")
        rate_limit(cfg)

        roster = fetch_team_roster(team_id, season)
        player_ids = [entry["person"]["id"] for entry in roster]

        for pid in player_ids:
            if pid in seen:
                continue
            seen.add(pid)

            for gt in game_types:
                rate_limit(cfg)
                splits = fetch_player_pitching_stats(pid, season, gt)
                if splits:
                    for split in splits:
                        row = transform_pitching_stat(split, pid, season, gt)
                        if row["team_id"] is not None:
                            all_rows.append(row)

    logger.info(f"Total pitching stat rows: {len(all_rows)}")

    conn = get_connection(cfg)
    try:
        count = upsert_rows(conn, TABLE, all_rows, CONFLICT_COLS)
        logger.info(f"Upserted {count} pitching stats into {TABLE}")
    finally:
        conn.close()

    return count


if __name__ == "__main__":
    run()

import sys
import os
import time
from datetime import datetime, timedelta

import pandas as pd

from utils import load_config, get_connection, setup_logging, retry, rate_limit, upsert_rows

TABLE = "raw_mlb.raw_statcast"

# Map pybaseball DataFrame columns to our DB columns
COLUMN_MAP = {
    "game_pk": "game_pk",
    "game_date": "game_date",
    "game_year": "game_year",
    "batter": "batter",
    "pitcher": "pitcher",
    "player_name": "batter_name",
    "pitcher_name": "pitcher_name",  # may not exist in older data
    "events": "events",
    "description": "description",
    "zone": "zone",
    "stand": "stand",
    "p_throws": "p_throws",
    "home_team": "home_team",
    "away_team": "away_team",
    "type": "type",
    "pitch_type": "pitch_type",
    "pitch_name": "pitch_name",
    "release_speed": "release_speed",
    "release_spin_rate": "release_spin_rate",
    "release_extension": "release_extension",
    "release_pos_x": "release_pos_x",
    "release_pos_z": "release_pos_z",
    "pfx_x": "pfx_x",
    "pfx_z": "pfx_z",
    "plate_x": "plate_x",
    "plate_z": "plate_z",
    "vx0": "vx0",
    "vy0": "vy0",
    "vz0": "vz0",
    "ax": "ax",
    "ay": "ay",
    "az": "az",
    "sz_top": "sz_top",
    "sz_bot": "sz_bot",
    "effective_speed": "effective_speed",
    "launch_speed": "launch_speed",
    "launch_angle": "launch_angle",
    "hit_distance_sc": "hit_distance_sc",
    "hc_x": "hc_x",
    "hc_y": "hc_y",
    "estimated_ba_using_speedangle": "estimated_ba_using_speedangle",
    "estimated_woba_using_speedangle": "estimated_woba_using_speedangle",
    "babip_value": "babip_value",
    "iso_value": "iso_value",
    "launch_speed_angle": "launch_speed_angle",
    "at_bat_number": "at_bat_number",
    "pitch_number": "pitch_number",
    "inning": "inning",
    "inning_topbot": "inning_topbot",
    "outs_when_up": "outs_when_up",
    "balls": "balls",
    "strikes": "strikes",
    "on_1b": "on_1b",
    "on_2b": "on_2b",
    "on_3b": "on_3b",
    "if_fielding_alignment": "if_fielding_alignment",
    "of_fielding_alignment": "of_fielding_alignment",
}

# DB columns that hold the data (excluding id and loaded_at)
DB_COLUMNS = list(COLUMN_MAP.values())


def _date_chunks(start_date, end_date, chunk_days):
    """Split a date range into chunks of chunk_days."""
    start = datetime.strptime(start_date, "%Y-%m-%d")
    end = datetime.strptime(end_date, "%Y-%m-%d")
    while start <= end:
        chunk_end = min(start + timedelta(days=chunk_days - 1), end)
        yield start.strftime("%Y-%m-%d"), chunk_end.strftime("%Y-%m-%d")
        start = chunk_end + timedelta(days=1)


@retry(max_retries=3, backoff_factor=2)
def fetch_statcast_chunk(start_dt, end_dt):
    from pybaseball import statcast
    df = statcast(start_dt, end_dt, verbose=False)
    return df


def _safe_val(val):
    """Convert pandas/numpy values to Python-native types safe for psycopg2."""
    if pd.isna(val):
        return None
    if hasattr(val, "item"):  # numpy scalar
        return val.item()
    return val


def transform_statcast_df(df):
    """Convert a pybaseball DataFrame into a list of dicts matching the DB schema."""
    rows = []
    # Handle the batter_name mapping: pybaseball uses 'player_name' for batter name
    # and may or may not have 'pitcher_name'
    has_pitcher_name = "pitcher_name" in df.columns

    for _, row in df.iterrows():
        record = {}
        for src_col, db_col in COLUMN_MAP.items():
            if src_col == "pitcher_name" and not has_pitcher_name:
                record[db_col] = None
                continue
            if src_col in df.columns:
                record[db_col] = _safe_val(row[src_col])
            else:
                record[db_col] = None

        # Convert game_date to string if it's a Timestamp
        if record["game_date"] is not None and not isinstance(record["game_date"], str):
            record["game_date"] = str(record["game_date"])[:10]

        # Ensure integer fields are proper ints or None
        int_fields = [
            "game_pk", "game_year", "batter", "pitcher", "zone",
            "release_spin_rate", "launch_speed_angle", "at_bat_number",
            "pitch_number", "inning", "outs_when_up", "balls", "strikes",
            "on_1b", "on_2b", "on_3b",
        ]
        for f in int_fields:
            if record.get(f) is not None:
                try:
                    record[f] = int(record[f])
                except (ValueError, TypeError):
                    record[f] = None

        # Skip rows missing required fields
        if record["batter"] is None or record["pitcher"] is None or record["game_date"] is None:
            continue

        rows.append(record)
    return rows


def run(cfg=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)
    logger.info("Starting Statcast extraction")

    sc_cfg = cfg.get("statcast", {})
    start_date = sc_cfg.get("start_date", "2024-03-28")
    end_date = sc_cfg.get("end_date", "2024-09-29")
    chunk_days = sc_cfg.get("chunk_days", 5)
    statcast_delay = cfg.get("rate_limit", {}).get("statcast_delay", 2.0)

    chunks = list(_date_chunks(start_date, end_date, chunk_days))
    logger.info(
        f"Statcast extraction: {start_date} to {end_date}, "
        f"{len(chunks)} chunks of {chunk_days} days"
    )

    conn = get_connection(cfg)
    total_rows = 0

    try:
        for i, (chunk_start, chunk_end) in enumerate(chunks, 1):
            logger.info(f"Chunk {i}/{len(chunks)}: {chunk_start} to {chunk_end}")
            try:
                df = fetch_statcast_chunk(chunk_start, chunk_end)
            except Exception as e:
                logger.error(f"Failed to fetch chunk {chunk_start}-{chunk_end}: {e}")
                continue

            if df is None or df.empty:
                logger.info(f"  No data for {chunk_start} to {chunk_end}")
                time.sleep(statcast_delay)
                continue

            rows = transform_statcast_df(df)
            logger.info(f"  Fetched {len(df)} raw rows, transformed {len(rows)} valid rows")

            if rows:
                # Use batch insert without ON CONFLICT since raw_statcast has no unique
                # constraint beyond the serial id. We use a simple INSERT approach.
                columns = list(rows[0].keys())
                col_list = ", ".join(columns)
                placeholders = ", ".join([f"%({c})s" for c in columns])
                sql = f"""
                    INSERT INTO {TABLE} ({col_list})
                    VALUES ({placeholders})
                """
                import psycopg2.extras
                with conn.cursor() as cur:
                    psycopg2.extras.execute_batch(cur, sql, rows, page_size=1000)
                conn.commit()
                total_rows += len(rows)
                logger.info(f"  Inserted {len(rows)} rows into {TABLE}")

            time.sleep(statcast_delay)

    finally:
        conn.close()

    logger.info(f"Statcast extraction complete. Total rows inserted: {total_rows}")
    return total_rows


if __name__ == "__main__":
    run()

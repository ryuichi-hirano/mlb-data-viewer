import functools
import logging
import os
import sys
import time

import psycopg2
import psycopg2.extras
import yaml

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "..", "config.yml")


def load_config(path=None):
    with open(path or CONFIG_PATH) as f:
        return yaml.safe_load(f)


def get_connection(cfg=None):
    if cfg is None:
        cfg = load_config()
    db = cfg["database"]
    return psycopg2.connect(
        host=db["host"],
        port=db["port"],
        dbname=db["dbname"],
        user=db["user"],
        password=db["password"],
    )


def setup_logging(cfg=None):
    if cfg is None:
        cfg = load_config()
    log_cfg = cfg.get("logging", {})
    log_file = log_cfg.get("file")
    if log_file:
        os.makedirs(os.path.dirname(log_file), exist_ok=True)
    logging.basicConfig(
        level=getattr(logging, log_cfg.get("level", "INFO")),
        format=log_cfg.get("format", "%(asctime)s - %(name)s - %(levelname)s - %(message)s"),
        handlers=[
            logging.StreamHandler(sys.stdout),
            *([] if not log_file else [logging.FileHandler(log_file)]),
        ],
    )
    return logging.getLogger("mlb_extraction")


def retry(max_retries=3, backoff_factor=2):
    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            logger = logging.getLogger("mlb_extraction")
            for attempt in range(1, max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_retries:
                        logger.error(f"{func.__name__} failed after {max_retries} attempts: {e}")
                        raise
                    wait = backoff_factor ** attempt
                    logger.warning(
                        f"{func.__name__} attempt {attempt}/{max_retries} failed: {e}. "
                        f"Retrying in {wait}s..."
                    )
                    time.sleep(wait)
        return wrapper
    return decorator


def rate_limit(cfg, key="request_delay"):
    delay = cfg.get("rate_limit", {}).get(key, 1.0)
    time.sleep(delay)


def upsert_rows(conn, table, rows, conflict_columns, update_columns=None):
    if not rows:
        return 0
    columns = list(rows[0].keys())
    if update_columns is None:
        update_columns = [c for c in columns if c not in conflict_columns and c != "loaded_at"]
    col_list = ", ".join(columns)
    placeholders = ", ".join([f"%({c})s" for c in columns])
    conflict_list = ", ".join(conflict_columns)
    if update_columns:
        update_set = ", ".join([f"{c} = EXCLUDED.{c}" for c in update_columns])
        update_clause = f"DO UPDATE SET {update_set}, loaded_at = NOW()"
    else:
        update_clause = "DO NOTHING"
    sql = f"""
        INSERT INTO {table} ({col_list})
        VALUES ({placeholders})
        ON CONFLICT ({conflict_list}) {update_clause}
    """
    with conn.cursor() as cur:
        psycopg2.extras.execute_batch(cur, sql, rows, page_size=500)
    conn.commit()
    return len(rows)

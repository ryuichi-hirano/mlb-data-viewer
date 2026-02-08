"""
MLB Data Extraction Orchestrator

Runs all extraction scripts in the correct dependency order:
1. Teams (no dependencies)
2. Players (depends on teams for FK)
3. Schedule (depends on teams for FK)
4. Games (depends on teams for FK)
5. Batting stats (depends on players, teams)
6. Pitching stats (depends on players, teams)
7. Statcast (independent pitch-level data)
"""

import argparse
import sys
import time

from utils import load_config, setup_logging

# Extraction modules in dependency order
EXTRACTION_ORDER = [
    ("teams", "extract_teams"),
    ("players", "extract_players"),
    ("schedule", "extract_schedule"),
    ("games", "extract_games"),
    ("batting_stats", "extract_batting_stats"),
    ("pitching_stats", "extract_pitching_stats"),
    ("statcast", "extract_statcast"),
]


def run_all(cfg=None, skip=None, only=None):
    if cfg is None:
        cfg = load_config()
    logger = setup_logging(cfg)

    skip = set(skip or [])
    only = set(only) if only else None

    steps = []
    for name, module_name in EXTRACTION_ORDER:
        if only and name not in only:
            continue
        if name in skip:
            continue
        steps.append((name, module_name))

    logger.info(f"Running {len(steps)} extraction steps: {[s[0] for s in steps]}")

    results = {}
    failed = []

    for name, module_name in steps:
        logger.info(f"{'='*60}")
        logger.info(f"Starting extraction: {name}")
        logger.info(f"{'='*60}")
        start_time = time.time()

        try:
            module = __import__(module_name)
            count = module.run(cfg)
            elapsed = time.time() - start_time
            results[name] = {"status": "success", "rows": count, "elapsed": elapsed}
            logger.info(f"Completed {name}: {count} rows in {elapsed:.1f}s")
        except Exception as e:
            elapsed = time.time() - start_time
            results[name] = {"status": "failed", "error": str(e), "elapsed": elapsed}
            failed.append(name)
            logger.error(f"Failed {name} after {elapsed:.1f}s: {e}")

    # Summary
    logger.info(f"\n{'='*60}")
    logger.info("EXTRACTION SUMMARY")
    logger.info(f"{'='*60}")
    for name, result in results.items():
        if result["status"] == "success":
            logger.info(f"  {name}: {result['rows']} rows ({result['elapsed']:.1f}s)")
        else:
            logger.error(f"  {name}: FAILED - {result['error']} ({result['elapsed']:.1f}s)")

    if failed:
        logger.error(f"\n{len(failed)} step(s) failed: {failed}")
        return 1
    else:
        logger.info(f"\nAll {len(results)} steps completed successfully")
        return 0


def main():
    parser = argparse.ArgumentParser(description="MLB Data Extraction Orchestrator")
    parser.add_argument(
        "--skip",
        nargs="*",
        default=[],
        choices=[name for name, _ in EXTRACTION_ORDER],
        help="Steps to skip",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        choices=[name for name, _ in EXTRACTION_ORDER],
        help="Run only these steps (in dependency order)",
    )
    args = parser.parse_args()

    sys.exit(run_all(skip=args.skip, only=args.only))


if __name__ == "__main__":
    main()

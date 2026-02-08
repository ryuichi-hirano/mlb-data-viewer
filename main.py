"""
MLB Data Viewer - Main Entry Point

Usage:
    python main.py                     # Run full extraction pipeline
    python main.py --skip statcast     # Skip Statcast (slow)
    python main.py --only teams players # Run only specific steps
"""

import sys
import os

# Ensure scripts directory is on the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "scripts"))

from scripts.run_extraction import run_all


def main():
    import argparse

    parser = argparse.ArgumentParser(description="MLB Data Viewer - Data Pipeline")
    parser.add_argument(
        "--skip",
        nargs="*",
        default=[],
        help="Extraction steps to skip (teams, players, schedule, games, batting_stats, pitching_stats, statcast)",
    )
    parser.add_argument(
        "--only",
        nargs="*",
        default=None,
        help="Run only these extraction steps",
    )
    args = parser.parse_args()

    sys.exit(run_all(skip=args.skip, only=args.only))


if __name__ == "__main__":
    main()

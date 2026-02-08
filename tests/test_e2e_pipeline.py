"""
MLB Data Pipeline - End-to-End Data Quality Tests

Validates data integrity across the full pipeline:
  API extraction → raw_mlb → staging → intermediate → marts → Evidence queries

Usage:
    python -m pytest tests/test_e2e_pipeline.py -v
    python tests/test_e2e_pipeline.py  # standalone

Requires a running PostgreSQL database with populated data.
"""

import os
import sys
import pytest
import psycopg2

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
from utils import load_config, get_connection


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def cfg():
    return load_config()


@pytest.fixture(scope="session")
def conn(cfg):
    c = get_connection(cfg)
    yield c
    c.close()


def _query_one(conn, sql):
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchone()


def _query_all(conn, sql):
    with conn.cursor() as cur:
        cur.execute(sql)
        return cur.fetchall()


def _query_scalar(conn, sql):
    row = _query_one(conn, sql)
    return row[0] if row else None


# ===========================================================================
# 1. RAW LAYER - Source data existence and basic integrity
# ===========================================================================

class TestRawLayer:
    """Validate that raw tables have data loaded from extraction scripts."""

    def test_raw_teams_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_teams")
        assert count is not None and count >= 30, f"Expected >= 30 teams, got {count}"

    def test_raw_players_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_players")
        assert count is not None and count >= 100, f"Expected >= 100 players, got {count}"

    def test_raw_games_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_games")
        assert count is not None and count >= 100, f"Expected >= 100 games, got {count}"

    def test_raw_schedule_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_schedule")
        assert count is not None and count >= 100, f"Expected >= 100 schedule entries, got {count}"

    def test_raw_batting_stats_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_batting_stats")
        assert count is not None and count >= 100, f"Expected >= 100 batting stat rows, got {count}"

    def test_raw_pitching_stats_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_pitching_stats")
        assert count is not None and count >= 50, f"Expected >= 50 pitching stat rows, got {count}"

    def test_raw_statcast_populated(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_statcast")
        assert count is not None and count >= 1000, f"Expected >= 1000 statcast rows, got {count}"

    def test_raw_teams_no_null_pk(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_teams WHERE team_id IS NULL")
        assert count == 0, f"Found {count} teams with NULL team_id"

    def test_raw_players_no_null_pk(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_players WHERE player_id IS NULL")
        assert count == 0, f"Found {count} players with NULL player_id"

    def test_raw_games_no_null_pk(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_games WHERE game_pk IS NULL")
        assert count == 0, f"Found {count} games with NULL game_pk"

    def test_raw_players_fk_to_teams(self, conn):
        """Players' current_team_id should reference existing teams."""
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM raw_mlb.raw_players p
            WHERE p.current_team_id IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1 FROM raw_mlb.raw_teams t WHERE t.team_id = p.current_team_id
              )
        """)
        assert orphans == 0, f"Found {orphans} players referencing non-existent teams"

    def test_raw_games_fk_to_teams(self, conn):
        """Game home/away team IDs should reference existing teams."""
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM raw_mlb.raw_games g
            WHERE NOT EXISTS (SELECT 1 FROM raw_mlb.raw_teams t WHERE t.team_id = g.home_team_id)
               OR NOT EXISTS (SELECT 1 FROM raw_mlb.raw_teams t WHERE t.team_id = g.away_team_id)
        """)
        assert orphans == 0, f"Found {orphans} games referencing non-existent teams"


# ===========================================================================
# 2. STAGING LAYER - Cleansed data quality
# ===========================================================================

class TestStagingLayer:
    """Validate staging views/tables have expected structure and data."""

    def test_stg_teams_count_matches_raw(self, conn):
        raw = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_teams")
        stg = _query_scalar(conn, "SELECT count(*) FROM staging.stg_teams")
        assert raw == stg, f"raw_teams={raw} != stg_teams={stg}"

    def test_stg_players_count_matches_raw(self, conn):
        raw = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_players")
        stg = _query_scalar(conn, "SELECT count(*) FROM staging.stg_players")
        assert raw == stg, f"raw_players={raw} != stg_players={stg}"

    def test_stg_batting_avg_range(self, conn):
        violations = _query_scalar(conn, """
            SELECT count(*) FROM staging.stg_batting_stats
            WHERE batting_average IS NOT NULL
              AND (batting_average < 0 OR batting_average > 1)
        """)
        assert violations == 0, f"Found {violations} batting avg values outside [0, 1]"

    def test_stg_era_non_negative(self, conn):
        violations = _query_scalar(conn, """
            SELECT count(*) FROM staging.stg_pitching_stats
            WHERE era IS NOT NULL AND era < 0
        """)
        assert violations == 0, f"Found {violations} negative ERA values"

    def test_stg_statcast_pitch_result_types(self, conn):
        bad = _query_scalar(conn, """
            SELECT count(*) FROM staging.stg_statcast
            WHERE pitch_result_type IS NOT NULL
              AND pitch_result_type NOT IN ('B', 'S', 'X')
        """)
        assert bad == 0, f"Found {bad} invalid pitch_result_type values"

    def test_stg_games_completed_have_scores(self, conn):
        bad = _query_scalar(conn, """
            SELECT count(*) FROM staging.stg_games
            WHERE game_status_code = 'F'
              AND (home_score IS NULL OR away_score IS NULL)
        """)
        assert bad == 0, f"Found {bad} completed games missing scores"


# ===========================================================================
# 3. INTERMEDIATE LAYER - Aggregation and calculation correctness
# ===========================================================================

class TestIntermediateLayer:
    """Validate intermediate aggregations and derived calculations."""

    def test_int_batting_ops_consistency(self, conn):
        """OPS should approximately equal OBP + SLG."""
        violations = _query_scalar(conn, """
            SELECT count(*) FROM intermediate.int_player_season_batting
            WHERE on_base_percentage IS NOT NULL
              AND slugging_percentage IS NOT NULL
              AND on_base_plus_slugging IS NOT NULL
              AND abs(on_base_plus_slugging - (on_base_percentage + slugging_percentage)) > 0.005
        """)
        assert violations == 0, f"Found {violations} rows with OPS != OBP + SLG"

    def test_int_game_results_two_rows_per_game(self, conn):
        """Each game should produce exactly 2 rows (home + away)."""
        bad = _query_scalar(conn, """
            SELECT count(*) FROM (
                SELECT game_pk, count(*) as cnt
                FROM intermediate.int_game_results
                GROUP BY game_pk
                HAVING count(*) != 2
            ) sub
        """)
        assert bad == 0, f"Found {bad} games without exactly 2 result rows"

    def test_int_game_results_one_winner_per_game(self, conn):
        bad = _query_scalar(conn, """
            SELECT count(*) FROM (
                SELECT game_pk
                FROM intermediate.int_game_results
                GROUP BY game_pk
                HAVING sum(CASE WHEN is_win THEN 1 ELSE 0 END) != 1
            ) sub
        """)
        assert bad == 0, f"Found {bad} games without exactly 1 winner"

    def test_int_standings_wins_losses_equal_games(self, conn):
        violations = _query_scalar(conn, """
            SELECT count(*) FROM intermediate.int_team_standings
            WHERE wins + losses != games_played
        """)
        assert violations == 0, f"Found {violations} standings rows where W+L != GP"

    def test_int_statcast_player_roles(self, conn):
        bad = _query_scalar(conn, """
            SELECT count(*) FROM intermediate.int_statcast_metrics
            WHERE player_role NOT IN ('batter', 'pitcher')
        """)
        assert bad == 0, f"Found {bad} rows with invalid player_role"

    def test_int_pitching_fip_reasonable(self, conn):
        """FIP should be between -5 and 30 for any pitcher with IP > 0."""
        violations = _query_scalar(conn, """
            SELECT count(*) FROM intermediate.int_player_season_pitching
            WHERE innings_pitched > 0
              AND fip IS NOT NULL
              AND (fip < -5 OR fip > 30)
        """)
        assert violations == 0, f"Found {violations} pitchers with unreasonable FIP"


# ===========================================================================
# 4. MARTS LAYER - Final business logic
# ===========================================================================

class TestMartsLayer:
    """Validate final marts tables for dashboard consumption."""

    def test_dim_teams_unique_ids(self, conn):
        total = _query_scalar(conn, "SELECT count(*) FROM marts.dim_teams")
        unique = _query_scalar(conn, "SELECT count(DISTINCT team_id) FROM marts.dim_teams")
        assert total == unique, f"dim_teams has duplicates: {total} total vs {unique} unique"

    def test_dim_players_unique_ids(self, conn):
        total = _query_scalar(conn, "SELECT count(*) FROM marts.dim_players")
        unique = _query_scalar(conn, "SELECT count(DISTINCT player_id) FROM marts.dim_players")
        assert total == unique, f"dim_players has duplicates: {total} total vs {unique} unique"

    def test_fct_game_summary_unique_games(self, conn):
        total = _query_scalar(conn, "SELECT count(*) FROM marts.fct_game_summary")
        unique = _query_scalar(conn, "SELECT count(DISTINCT game_pk) FROM marts.fct_game_summary")
        assert total == unique, f"fct_game_summary has duplicates: {total} total vs {unique} unique"

    def test_fct_batting_performance_has_data(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM marts.fct_batting_performance")
        assert count > 0, "fct_batting_performance is empty"

    def test_fct_pitching_performance_has_data(self, conn):
        count = _query_scalar(conn, "SELECT count(*) FROM marts.fct_pitching_performance")
        assert count > 0, "fct_pitching_performance is empty"

    def test_fct_statcast_leaders_roles(self, conn):
        bad = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_statcast_leaders
            WHERE player_role NOT IN ('batter', 'pitcher')
        """)
        assert bad == 0, f"Found {bad} statcast leaders with invalid role"

    def test_fct_team_season_summary_pythagorean(self, conn):
        """Pythagorean wins should be within 15 of actual wins."""
        violations = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_team_season_summary
            WHERE pythagorean_wins IS NOT NULL
              AND wins IS NOT NULL
              AND abs(pythagorean_wins - wins) > 15
        """)
        assert violations == 0, f"Found {violations} teams with unreasonable Pythagorean expectation"

    def test_fct_batting_walk_pct_range(self, conn):
        violations = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_batting_performance
            WHERE walk_pct IS NOT NULL
              AND (walk_pct < 0 OR walk_pct > 1)
        """)
        assert violations == 0, f"Found {violations} batting rows with walk_pct outside [0, 1]"

    def test_fct_batting_strikeout_pct_range(self, conn):
        violations = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_batting_performance
            WHERE strikeout_pct IS NOT NULL
              AND (strikeout_pct < 0 OR strikeout_pct > 1)
        """)
        assert violations == 0, f"Found {violations} batting rows with strikeout_pct outside [0, 1]"


# ===========================================================================
# 5. CROSS-LAYER TRACEABILITY (E2E)
# ===========================================================================

class TestE2ETraceability:
    """Validate data flows correctly across pipeline layers."""

    def test_team_count_raw_to_marts(self, conn):
        """Teams should flow from raw through all layers without loss."""
        raw = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_teams")
        stg = _query_scalar(conn, "SELECT count(*) FROM staging.stg_teams")
        marts = _query_scalar(conn, "SELECT count(*) FROM marts.dim_teams")
        assert raw == stg == marts, f"Team count mismatch: raw={raw}, stg={stg}, marts={marts}"

    def test_player_count_raw_to_marts(self, conn):
        """Players should flow from raw to marts without loss."""
        raw = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_players")
        stg = _query_scalar(conn, "SELECT count(*) FROM staging.stg_players")
        marts = _query_scalar(conn, "SELECT count(*) FROM marts.dim_players")
        assert raw == stg == marts, f"Player count mismatch: raw={raw}, stg={stg}, marts={marts}"

    def test_games_raw_to_stg_no_loss(self, conn):
        """All raw games should appear in staging."""
        raw = _query_scalar(conn, "SELECT count(*) FROM raw_mlb.raw_games")
        stg = _query_scalar(conn, "SELECT count(*) FROM staging.stg_games")
        assert raw == stg, f"Games count mismatch: raw={raw}, stg={stg}"

    def test_fct_game_summary_subset_of_stg(self, conn):
        """fct_game_summary should only contain games that exist in staging."""
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_game_summary gs
            WHERE NOT EXISTS (
                SELECT 1 FROM staging.stg_games sg WHERE sg.game_pk = gs.game_pk
            )
        """)
        assert orphans == 0, f"Found {orphans} game summaries not traceable to staging"

    def test_batting_perf_players_exist_in_dim(self, conn):
        """All players in fct_batting_performance should exist in dim_players."""
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_batting_performance bp
            WHERE NOT EXISTS (
                SELECT 1 FROM marts.dim_players dp WHERE dp.player_id = bp.player_id
            )
        """)
        assert orphans == 0, f"Found {orphans} batting rows referencing non-existent players"

    def test_pitching_perf_players_exist_in_dim(self, conn):
        """All players in fct_pitching_performance should exist in dim_players."""
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_pitching_performance pp
            WHERE NOT EXISTS (
                SELECT 1 FROM marts.dim_players dp WHERE dp.player_id = pp.player_id
            )
        """)
        assert orphans == 0, f"Found {orphans} pitching rows referencing non-existent players"

    def test_statcast_leaders_players_exist_in_dim(self, conn):
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_statcast_leaders sl
            WHERE NOT EXISTS (
                SELECT 1 FROM marts.dim_players dp WHERE dp.player_id = sl.player_id
            )
        """)
        assert orphans == 0, f"Found {orphans} statcast leaders not in dim_players"

    def test_team_season_summary_teams_exist_in_dim(self, conn):
        orphans = _query_scalar(conn, """
            SELECT count(*) FROM marts.fct_team_season_summary ts
            WHERE NOT EXISTS (
                SELECT 1 FROM marts.dim_teams dt WHERE dt.team_id = ts.team_id
            )
        """)
        assert orphans == 0, f"Found {orphans} team summaries not in dim_teams"


# ===========================================================================
# 6. DATA QUALITY PROFILING
# ===========================================================================

class TestDataQualityProfile:
    """Profile null rates and detect data quality anomalies."""

    def test_raw_batting_null_rate_batting_avg(self, conn):
        """Batting average NULL rate should be < 20%."""
        total, nulls = _query_one(conn, """
            SELECT count(*), count(*) - count(batting_average)
            FROM raw_mlb.raw_batting_stats
        """)
        if total > 0:
            null_rate = nulls / total
            assert null_rate < 0.20, f"Batting avg NULL rate: {null_rate:.1%} (> 20%)"

    def test_raw_pitching_null_rate_era(self, conn):
        """ERA NULL rate should be < 20%."""
        total, nulls = _query_one(conn, """
            SELECT count(*), count(*) - count(era)
            FROM raw_mlb.raw_pitching_stats
        """)
        if total > 0:
            null_rate = nulls / total
            assert null_rate < 0.20, f"ERA NULL rate: {null_rate:.1%} (> 20%)"

    def test_statcast_release_speed_null_rate(self, conn):
        """Release speed NULL rate should be < 15%."""
        total, nulls = _query_one(conn, """
            SELECT count(*), count(*) - count(release_speed)
            FROM raw_mlb.raw_statcast
        """)
        if total > 0:
            null_rate = nulls / total
            assert null_rate < 0.15, f"Release speed NULL rate: {null_rate:.1%} (> 15%)"

    def test_statcast_launch_speed_null_rate(self, conn):
        """Launch speed should be NULL only for non-batted-ball events (expect ~65-75% NULL)."""
        total, nulls = _query_one(conn, """
            SELECT count(*), count(*) - count(launch_speed)
            FROM raw_mlb.raw_statcast
        """)
        if total > 0:
            null_rate = nulls / total
            # launch_speed is only populated for batted balls (~25-35% of pitches)
            assert null_rate < 0.85, f"Launch speed NULL rate: {null_rate:.1%} (> 85%)"


# ===========================================================================
# Standalone runner
# ===========================================================================

if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-v", "--tb=short"]))

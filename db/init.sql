-- =============================================================================
-- MLB Data Viewer - Database Initialization Script
-- =============================================================================
-- Run this script to set up a fresh database:
--   psql -U postgres -f db/init.sql
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Create database (run as superuser)
-- ---------------------------------------------------------------------------
-- Note: Uncomment below if you want to create the database from this script.
-- Otherwise, create the database manually first and then run the schema.
--
-- DROP DATABASE IF EXISTS mlb_data;
-- CREATE DATABASE mlb_data
--     ENCODING 'UTF8'
--     LC_COLLATE 'en_US.UTF-8'
--     LC_CTYPE 'en_US.UTF-8';

-- ---------------------------------------------------------------------------
-- 2. Connect to the target database
-- ---------------------------------------------------------------------------
\connect mlb_data;

-- ---------------------------------------------------------------------------
-- 3. Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- Trigram index support for text search

-- ---------------------------------------------------------------------------
-- 4. Apply schema DDL
-- ---------------------------------------------------------------------------
\i db/schema.sql

-- ---------------------------------------------------------------------------
-- 5. Seed data: MLB Teams (2024 season, 30 active franchises)
-- ---------------------------------------------------------------------------
INSERT INTO raw_mlb.raw_teams (team_id, name, abbreviation, team_name, location_name, league_name, division_name, active)
VALUES
    -- American League East
    (110, 'Baltimore Orioles',     'BAL', 'Orioles',    'Baltimore',    'American League', 'AL East', TRUE),
    (111, 'Boston Red Sox',        'BOS', 'Red Sox',    'Boston',       'American League', 'AL East', TRUE),
    (147, 'New York Yankees',      'NYY', 'Yankees',    'New York',     'American League', 'AL East', TRUE),
    (139, 'Tampa Bay Rays',        'TB',  'Rays',       'St. Petersburg','American League','AL East', TRUE),
    (141, 'Toronto Blue Jays',     'TOR', 'Blue Jays',  'Toronto',      'American League', 'AL East', TRUE),
    -- American League Central
    (145, 'Chicago White Sox',     'CWS', 'White Sox',  'Chicago',      'American League', 'AL Central', TRUE),
    (114, 'Cleveland Guardians',   'CLE', 'Guardians',  'Cleveland',    'American League', 'AL Central', TRUE),
    (116, 'Detroit Tigers',        'DET', 'Tigers',     'Detroit',      'American League', 'AL Central', TRUE),
    (118, 'Kansas City Royals',    'KC',  'Royals',     'Kansas City',  'American League', 'AL Central', TRUE),
    (142, 'Minnesota Twins',       'MIN', 'Twins',      'Minneapolis',  'American League', 'AL Central', TRUE),
    -- American League West
    (117, 'Houston Astros',        'HOU', 'Astros',     'Houston',      'American League', 'AL West', TRUE),
    (108, 'Los Angeles Angels',    'LAA', 'Angels',     'Anaheim',      'American League', 'AL West', TRUE),
    (133, 'Oakland Athletics',     'OAK', 'Athletics',  'Oakland',      'American League', 'AL West', TRUE),
    (136, 'Seattle Mariners',      'SEA', 'Mariners',   'Seattle',      'American League', 'AL West', TRUE),
    (140, 'Texas Rangers',         'TEX', 'Rangers',    'Arlington',    'American League', 'AL West', TRUE),
    -- National League East
    (144, 'Atlanta Braves',        'ATL', 'Braves',     'Atlanta',      'National League', 'NL East', TRUE),
    (146, 'Miami Marlins',         'MIA', 'Marlins',    'Miami',        'National League', 'NL East', TRUE),
    (121, 'New York Mets',         'NYM', 'Mets',       'New York',     'National League', 'NL East', TRUE),
    (143, 'Philadelphia Phillies', 'PHI', 'Phillies',   'Philadelphia', 'National League', 'NL East', TRUE),
    (120, 'Washington Nationals',  'WSH', 'Nationals',  'Washington',   'National League', 'NL East', TRUE),
    -- National League Central
    (112, 'Chicago Cubs',          'CHC', 'Cubs',       'Chicago',      'National League', 'NL Central', TRUE),
    (113, 'Cincinnati Reds',       'CIN', 'Reds',       'Cincinnati',   'National League', 'NL Central', TRUE),
    (158, 'Milwaukee Brewers',     'MIL', 'Brewers',    'Milwaukee',    'National League', 'NL Central', TRUE),
    (134, 'Pittsburgh Pirates',    'PIT', 'Pirates',    'Pittsburgh',   'National League', 'NL Central', TRUE),
    (138, 'St. Louis Cardinals',   'STL', 'Cardinals',  'St. Louis',    'National League', 'NL Central', TRUE),
    -- National League West
    (109, 'Arizona Diamondbacks',  'ARI', 'D-backs',    'Phoenix',      'National League', 'NL West', TRUE),
    (115, 'Colorado Rockies',      'COL', 'Rockies',    'Denver',       'National League', 'NL West', TRUE),
    (119, 'Los Angeles Dodgers',   'LAD', 'Dodgers',    'Los Angeles',  'National League', 'NL West', TRUE),
    (135, 'San Diego Padres',      'SD',  'Padres',     'San Diego',    'National League', 'NL West', TRUE),
    (137, 'San Francisco Giants',  'SF',  'Giants',     'San Francisco','National League', 'NL West', TRUE)
ON CONFLICT (team_id) DO UPDATE SET
    name            = EXCLUDED.name,
    abbreviation    = EXCLUDED.abbreviation,
    team_name       = EXCLUDED.team_name,
    location_name   = EXCLUDED.location_name,
    league_name     = EXCLUDED.league_name,
    division_name   = EXCLUDED.division_name,
    active          = EXCLUDED.active,
    loaded_at       = NOW();

-- ---------------------------------------------------------------------------
-- 6. Grant permissions for dbt role (optional - uncomment if using a dbt role)
-- ---------------------------------------------------------------------------
-- CREATE ROLE dbt_user LOGIN PASSWORD 'changeme';
--
-- GRANT USAGE ON SCHEMA raw_mlb TO dbt_user;
-- GRANT SELECT ON ALL TABLES IN SCHEMA raw_mlb TO dbt_user;
--
-- GRANT ALL ON SCHEMA staging TO dbt_user;
-- GRANT ALL ON SCHEMA intermediate TO dbt_user;
-- GRANT ALL ON SCHEMA marts TO dbt_user;
--
-- ALTER DEFAULT PRIVILEGES IN SCHEMA staging GRANT ALL ON TABLES TO dbt_user;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA intermediate GRANT ALL ON TABLES TO dbt_user;
-- ALTER DEFAULT PRIVILEGES IN SCHEMA marts GRANT ALL ON TABLES TO dbt_user;

-- ---------------------------------------------------------------------------
-- Done
-- ---------------------------------------------------------------------------

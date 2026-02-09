-- =============================================================================
-- MLB Data Viewer - Docker Database Initialization
-- =============================================================================
-- This script runs automatically on first container start via
-- docker-entrypoint-initdb.d when the postgres_data volume is empty.
--
-- The POSTGRES_DB environment variable creates the database automatically,
-- so we only need to set up schemas, tables, indexes, and seed data.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. Extensions
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------------------------------------------------------------------------
-- 2. Schema definitions
-- ---------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS raw_mlb;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS marts;

-- ---------------------------------------------------------------------------
-- 3. Raw tables
-- ---------------------------------------------------------------------------

-- Teams
CREATE TABLE raw_mlb.raw_teams (
    team_id         INTEGER PRIMARY KEY,
    name            TEXT NOT NULL,
    team_code       VARCHAR(10),
    abbreviation    VARCHAR(5) NOT NULL,
    team_name       TEXT,
    location_name   TEXT,
    league_id       INTEGER,
    league_name     VARCHAR(50),
    division_id     INTEGER,
    division_name   VARCHAR(50),
    venue_id        INTEGER,
    venue_name      TEXT,
    sport_id        INTEGER DEFAULT 1,
    active          BOOLEAN DEFAULT TRUE,
    first_year_of_play VARCHAR(4),
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Players
CREATE TABLE raw_mlb.raw_players (
    player_id       INTEGER PRIMARY KEY,
    full_name       TEXT NOT NULL,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    primary_number  VARCHAR(10),
    birth_date      DATE,
    birth_city      VARCHAR(100),
    birth_country   VARCHAR(100),
    height          VARCHAR(10),
    weight          INTEGER,
    primary_position_code   VARCHAR(5),
    primary_position_name   VARCHAR(50),
    primary_position_type   VARCHAR(50),
    bat_side        VARCHAR(5),
    pitch_hand      VARCHAR(5),
    current_team_id INTEGER REFERENCES raw_mlb.raw_teams(team_id),
    mlb_debut_date  DATE,
    active          BOOLEAN DEFAULT TRUE,
    loaded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Games
CREATE TABLE raw_mlb.raw_games (
    game_pk             INTEGER PRIMARY KEY,
    game_type           VARCHAR(5),
    season              INTEGER NOT NULL,
    game_date           DATE NOT NULL,
    game_datetime       TIMESTAMPTZ,
    status_code         VARCHAR(5),
    status_detail       VARCHAR(50),
    home_team_id        INTEGER NOT NULL REFERENCES raw_mlb.raw_teams(team_id),
    away_team_id        INTEGER NOT NULL REFERENCES raw_mlb.raw_teams(team_id),
    home_score          INTEGER,
    away_score          INTEGER,
    home_wins           INTEGER,
    home_losses         INTEGER,
    away_wins           INTEGER,
    away_losses         INTEGER,
    venue_id            INTEGER,
    venue_name          TEXT,
    winning_pitcher_id  INTEGER,
    losing_pitcher_id   INTEGER,
    save_pitcher_id     INTEGER,
    innings             INTEGER,
    day_night           VARCHAR(10),
    series_description  TEXT,
    series_game_number  INTEGER,
    double_header       VARCHAR(5),
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Batting stats (season-level aggregates)
CREATE TABLE raw_mlb.raw_batting_stats (
    id                  BIGSERIAL PRIMARY KEY,
    player_id           INTEGER NOT NULL REFERENCES raw_mlb.raw_players(player_id),
    season              INTEGER NOT NULL,
    team_id             INTEGER REFERENCES raw_mlb.raw_teams(team_id),
    league_id           INTEGER,
    game_type           VARCHAR(5) DEFAULT 'R',
    games_played        INTEGER,
    at_bats             INTEGER,
    runs                INTEGER,
    hits                INTEGER,
    doubles             INTEGER,
    triples             INTEGER,
    home_runs           INTEGER,
    rbi                 INTEGER,
    stolen_bases        INTEGER,
    caught_stealing     INTEGER,
    walks               INTEGER,
    strikeouts          INTEGER,
    batting_average     NUMERIC(5,3),
    obp                 NUMERIC(5,3),
    slg                 NUMERIC(5,3),
    ops                 NUMERIC(5,3),
    plate_appearances   INTEGER,
    total_bases         INTEGER,
    ground_into_dp      INTEGER,
    hit_by_pitch        INTEGER,
    sacrifice_bunts     INTEGER,
    sacrifice_flies     INTEGER,
    intentional_walks   INTEGER,
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (player_id, season, team_id, game_type)
);

-- Pitching stats (season-level aggregates)
CREATE TABLE raw_mlb.raw_pitching_stats (
    id                  BIGSERIAL PRIMARY KEY,
    player_id           INTEGER NOT NULL REFERENCES raw_mlb.raw_players(player_id),
    season              INTEGER NOT NULL,
    team_id             INTEGER REFERENCES raw_mlb.raw_teams(team_id),
    league_id           INTEGER,
    game_type           VARCHAR(5) DEFAULT 'R',
    wins                INTEGER,
    losses              INTEGER,
    era                 NUMERIC(6,2),
    games               INTEGER,
    games_started       INTEGER,
    games_finished      INTEGER,
    complete_games      INTEGER,
    shutouts            INTEGER,
    saves               INTEGER,
    save_opportunities  INTEGER,
    holds               INTEGER,
    blown_saves         INTEGER,
    innings_pitched     NUMERIC(6,1),
    hits_allowed        INTEGER,
    runs_allowed        INTEGER,
    earned_runs         INTEGER,
    home_runs_allowed   INTEGER,
    walks               INTEGER,
    strikeouts          INTEGER,
    hit_batsmen         INTEGER,
    whip                NUMERIC(5,2),
    batting_average_against NUMERIC(5,3),
    wild_pitches        INTEGER,
    balks               INTEGER,
    strikeout_walk_ratio NUMERIC(5,2),
    strikeouts_per_9    NUMERIC(5,2),
    walks_per_9         NUMERIC(5,2),
    hits_per_9          NUMERIC(5,2),
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (player_id, season, team_id, game_type)
);

-- Statcast pitch-level data
CREATE TABLE raw_mlb.raw_statcast (
    id                  BIGSERIAL PRIMARY KEY,
    game_pk             INTEGER,
    game_date           DATE NOT NULL,
    game_year           INTEGER,
    batter              INTEGER NOT NULL,
    pitcher             INTEGER NOT NULL,
    batter_name         TEXT,
    pitcher_name        TEXT,
    events              VARCHAR(50),
    description         TEXT,
    zone                INTEGER,
    stand               VARCHAR(5),
    p_throws            VARCHAR(5),
    home_team           VARCHAR(5),
    away_team           VARCHAR(5),
    type                VARCHAR(5),
    pitch_type          VARCHAR(10),
    pitch_name          VARCHAR(50),
    release_speed       NUMERIC(5,1),
    release_spin_rate   INTEGER,
    release_extension   NUMERIC(4,1),
    release_pos_x       NUMERIC(5,2),
    release_pos_z       NUMERIC(5,2),
    pfx_x               NUMERIC(6,2),
    pfx_z               NUMERIC(6,2),
    plate_x             NUMERIC(5,2),
    plate_z             NUMERIC(5,2),
    vx0                 NUMERIC(8,3),
    vy0                 NUMERIC(8,3),
    vz0                 NUMERIC(8,3),
    ax                  NUMERIC(8,3),
    ay                  NUMERIC(8,3),
    az                  NUMERIC(8,3),
    sz_top              NUMERIC(5,2),
    sz_bot              NUMERIC(5,2),
    effective_speed     NUMERIC(5,1),
    launch_speed        NUMERIC(5,1),
    launch_angle        NUMERIC(5,1),
    hit_distance_sc     NUMERIC(6,1),
    hc_x                NUMERIC(6,1),
    hc_y                NUMERIC(6,1),
    estimated_ba_using_speedangle   NUMERIC(5,3),
    estimated_woba_using_speedangle NUMERIC(5,3),
    babip_value         NUMERIC(5,3),
    iso_value           NUMERIC(5,3),
    launch_speed_angle  INTEGER,
    at_bat_number       INTEGER,
    pitch_number        INTEGER,
    inning              INTEGER,
    inning_topbot       VARCHAR(5),
    outs_when_up        INTEGER,
    balls               INTEGER,
    strikes             INTEGER,
    on_1b               INTEGER,
    on_2b               INTEGER,
    on_3b               INTEGER,
    if_fielding_alignment VARCHAR(50),
    of_fielding_alignment VARCHAR(50),
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Schedule
CREATE TABLE raw_mlb.raw_schedule (
    id                  BIGSERIAL PRIMARY KEY,
    game_pk             INTEGER NOT NULL,
    game_date           DATE NOT NULL,
    game_type           VARCHAR(5),
    season              INTEGER,
    status_code         VARCHAR(5),
    status_detail       VARCHAR(50),
    home_team_id        INTEGER REFERENCES raw_mlb.raw_teams(team_id),
    home_team_name      TEXT,
    away_team_id        INTEGER REFERENCES raw_mlb.raw_teams(team_id),
    away_team_name      TEXT,
    venue_id            INTEGER,
    venue_name          TEXT,
    game_datetime       TIMESTAMPTZ,
    day_night           VARCHAR(10),
    series_description  TEXT,
    series_game_number  INTEGER,
    games_in_series     INTEGER,
    double_header       VARCHAR(5),
    scheduled_innings   INTEGER DEFAULT 9,
    loaded_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (game_pk, game_date)
);

-- ---------------------------------------------------------------------------
-- 4. Indexes
-- ---------------------------------------------------------------------------

-- Players indexes
CREATE INDEX idx_raw_players_team ON raw_mlb.raw_players(current_team_id);
CREATE INDEX idx_raw_players_position ON raw_mlb.raw_players(primary_position_code);
CREATE INDEX idx_raw_players_name ON raw_mlb.raw_players(full_name);
CREATE INDEX idx_raw_players_active ON raw_mlb.raw_players(active) WHERE active = TRUE;

-- Games indexes
CREATE INDEX idx_raw_games_date ON raw_mlb.raw_games(game_date);
CREATE INDEX idx_raw_games_season ON raw_mlb.raw_games(season);
CREATE INDEX idx_raw_games_home_team ON raw_mlb.raw_games(home_team_id);
CREATE INDEX idx_raw_games_away_team ON raw_mlb.raw_games(away_team_id);
CREATE INDEX idx_raw_games_season_date ON raw_mlb.raw_games(season, game_date);
CREATE INDEX idx_raw_games_status ON raw_mlb.raw_games(status_code);

-- Batting stats indexes
CREATE INDEX idx_raw_batting_player ON raw_mlb.raw_batting_stats(player_id);
CREATE INDEX idx_raw_batting_season ON raw_mlb.raw_batting_stats(season);
CREATE INDEX idx_raw_batting_team ON raw_mlb.raw_batting_stats(team_id);
CREATE INDEX idx_raw_batting_player_season ON raw_mlb.raw_batting_stats(player_id, season);

-- Pitching stats indexes
CREATE INDEX idx_raw_pitching_player ON raw_mlb.raw_pitching_stats(player_id);
CREATE INDEX idx_raw_pitching_season ON raw_mlb.raw_pitching_stats(season);
CREATE INDEX idx_raw_pitching_team ON raw_mlb.raw_pitching_stats(team_id);
CREATE INDEX idx_raw_pitching_player_season ON raw_mlb.raw_pitching_stats(player_id, season);

-- Statcast indexes
CREATE INDEX idx_raw_statcast_game ON raw_mlb.raw_statcast(game_pk);
CREATE INDEX idx_raw_statcast_date ON raw_mlb.raw_statcast(game_date);
CREATE INDEX idx_raw_statcast_batter ON raw_mlb.raw_statcast(batter);
CREATE INDEX idx_raw_statcast_pitcher ON raw_mlb.raw_statcast(pitcher);
CREATE INDEX idx_raw_statcast_pitch_type ON raw_mlb.raw_statcast(pitch_type);
CREATE INDEX idx_raw_statcast_events ON raw_mlb.raw_statcast(events) WHERE events IS NOT NULL;
CREATE INDEX idx_raw_statcast_batter_date ON raw_mlb.raw_statcast(batter, game_date);
CREATE INDEX idx_raw_statcast_pitcher_date ON raw_mlb.raw_statcast(pitcher, game_date);
CREATE INDEX idx_raw_statcast_year ON raw_mlb.raw_statcast(game_year);

-- Schedule indexes
CREATE INDEX idx_raw_schedule_date ON raw_mlb.raw_schedule(game_date);
CREATE INDEX idx_raw_schedule_home ON raw_mlb.raw_schedule(home_team_id);
CREATE INDEX idx_raw_schedule_away ON raw_mlb.raw_schedule(away_team_id);
CREATE INDEX idx_raw_schedule_season ON raw_mlb.raw_schedule(season);
CREATE INDEX idx_raw_schedule_status ON raw_mlb.raw_schedule(status_code);

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

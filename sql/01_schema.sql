-- ============================================================
-- 01_schema.sql
-- Steam Gacha / Live-Service Activity Monitor
--
-- Purpose:
-- Create the main table for storing Steam player snapshots.
-- Each record represents one observation of a game at a
-- specific point in time.
-- ============================================================


CREATE TABLE IF NOT EXISTS steam_player_snapshots (
    id BIGSERIAL PRIMARY KEY,

    collected_at TIMESTAMP NOT NULL,

    appid INTEGER NOT NULL,

    name TEXT NOT NULL,

    category TEXT,

    current_players INTEGER,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- ============================================================
-- 03_activity_metrics.sql
-- Steam Gacha / Live-Service Activity Monitor
--
-- Purpose:
-- Calculate descriptive statistics for player activity.
--
-- Metrics:
--   observations
--   avg_players
--   min_players
--   max_players
--   stddev_players
--   coefficient_of_variation
-- ============================================================


CREATE OR REPLACE VIEW game_activity_metrics AS

SELECT
    appid,
    name,
    category,

    COUNT(*) AS observations,

    ROUND(
        AVG(current_players),
        2
    ) AS avg_players,

    MIN(current_players) AS min_players,

    MAX(current_players) AS max_players,

    ROUND(
        STDDEV(current_players),
        2
    ) AS stddev_players,

    ROUND(
        100.0 * STDDEV(current_players)
        / NULLIF(AVG(current_players), 0),
        2
    ) AS coefficient_of_variation,

    MIN(collected_at) AS first_snapshot,

    MAX(collected_at) AS last_snapshot

FROM steam_player_snapshots

GROUP BY
    appid,
    name,
    category;
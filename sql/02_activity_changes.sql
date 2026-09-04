-- ============================================================
-- 02_activity_changes.sql
-- Steam Gacha / Live-Service Activity Monitor
--
-- Purpose:
-- Calculate player activity changes between consecutive
-- snapshots for each game.
--
-- Metrics:
--   previous_players
--   player_change
--   change_percent
--   minutes_since_previous
-- ============================================================


CREATE OR REPLACE VIEW game_activity_changes AS

WITH snapshots AS (

    SELECT
        collected_at,
        appid,
        name,
        category,
        current_players,

        LAG(collected_at) OVER (
            PARTITION BY appid
            ORDER BY collected_at
        ) AS previous_collected_at,

        LAG(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at
        ) AS previous_players

    FROM steam_player_snapshots
)

SELECT
    collected_at,
    appid,
    name,
    category,

    current_players,

    previous_players,

    current_players - previous_players AS player_change,

    ROUND(
        100.0 * (current_players - previous_players)
        / NULLIF(previous_players, 0),
        2
    ) AS change_percent,

    ROUND(
        EXTRACT(
            EPOCH FROM (
                collected_at - previous_collected_at
            )
        ) / 60,
        2
    ) AS minutes_since_previous,

    previous_collected_at

FROM snapshots

WHERE previous_players IS NOT NULL;
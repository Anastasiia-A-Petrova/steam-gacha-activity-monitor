-- ============================================================
-- 04_activity_trends.sql
-- Steam Gacha / Live-Service Activity Monitor
--
-- Purpose:
-- Compare the first and latest available snapshots for each
-- game and classify the overall direction of activity.
--
-- Trend:
--   Growing
--   Declining
--   Stable
-- ============================================================


CREATE OR REPLACE VIEW game_activity_trends AS

WITH ranked_snapshots AS (

    SELECT
        appid,
        name,
        category,
        collected_at,
        current_players,

        FIRST_VALUE(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at
        ) AS first_players,

        FIRST_VALUE(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at DESC
        ) AS latest_players

    FROM steam_player_snapshots
)

SELECT DISTINCT
    appid,
    name,
    category,

    first_players,

    latest_players,

    latest_players - first_players AS total_change,

    ROUND(
        100.0 * (latest_players - first_players)
        / NULLIF(first_players, 0),
        2
    ) AS total_change_percent,

    CASE
        WHEN latest_players > first_players
            THEN 'Growing'

        WHEN latest_players < first_players
            THEN 'Declining'

        ELSE 'Stable'
    END AS trend

FROM ranked_snapshots;
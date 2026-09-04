CREATE OR REPLACE VIEW game_stability_analysis AS

SELECT
    appid,
    name,
    category,

    COUNT(*) AS observations,

    ROUND(AVG(current_players), 2) AS avg_players,

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

    ROUND(
        100.0 * (
            MAX(current_players) - MIN(current_players)
        )
        / NULLIF(AVG(current_players), 0),
        2
    ) AS activity_range_percent,

    MIN(collected_at) AS first_snapshot,

    MAX(collected_at) AS last_snapshot,

    CASE
        WHEN COUNT(*) < 28
            THEN 'Insufficient history'

        WHEN (
            100.0 * STDDEV(current_players)
            / NULLIF(AVG(current_players), 0)
        ) < 10
            THEN 'Very stable'

        WHEN (
            100.0 * STDDEV(current_players)
            / NULLIF(AVG(current_players), 0)
        ) < 25
            THEN 'Stable'

        WHEN (
            100.0 * STDDEV(current_players)
            / NULLIF(AVG(current_players), 0)
        ) < 50
            THEN 'Volatile'

        ELSE 'Highly volatile'
    END AS stability_level

FROM steam_player_snapshots

GROUP BY
    appid,
    name,
    category;
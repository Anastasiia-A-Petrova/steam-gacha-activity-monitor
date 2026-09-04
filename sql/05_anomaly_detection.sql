CREATE OR REPLACE VIEW game_activity_anomalies AS

WITH history AS (
    SELECT
        appid,
        name,
        category,
        collected_at,
        current_players,

        LAG(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at
        ) AS previous_players,

        COUNT(*) OVER (
            PARTITION BY appid
            ORDER BY collected_at
            ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING
        ) AS historical_observations,

        AVG(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at
            ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING
        ) AS baseline_avg,

        STDDEV(current_players) OVER (
            PARTITION BY appid
            ORDER BY collected_at
            ROWS BETWEEN 28 PRECEDING AND 1 PRECEDING
        ) AS baseline_stddev

    FROM steam_player_snapshots
),

metrics AS (
    SELECT
        appid,
        name,
        category,
        collected_at,
        current_players,
        previous_players,
        historical_observations,
        baseline_avg,
        baseline_stddev,

        ROUND(
            100.0 * (current_players - previous_players)
            / NULLIF(previous_players, 0),
            2
        ) AS change_percent,

        CASE
            WHEN historical_observations >= 28
                 AND baseline_stddev > 0
            THEN
                (current_players - baseline_avg)
                / baseline_stddev
            ELSE NULL
        END AS z_score

    FROM history
)

SELECT
    appid,
    name,
    category,
    collected_at,

    current_players,
    previous_players,

    historical_observations,

    ROUND(baseline_avg, 2) AS baseline_avg,
    ROUND(baseline_stddev, 2) AS baseline_stddev,

    change_percent,
    ROUND(z_score, 2) AS z_score,

    CASE
        WHEN historical_observations < 28
            THEN 'Insufficient history'

        WHEN z_score >= 2
            THEN 'High'

        WHEN z_score <= -2
            THEN 'Low'

        ELSE 'Normal'
    END AS anomaly_level

FROM metrics;
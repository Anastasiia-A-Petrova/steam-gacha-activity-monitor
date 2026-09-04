CREATE OR REPLACE VIEW game_activity_ranking AS

SELECT
    s.appid,
    s.name,
    s.category,

    s.observations,

    s.avg_players,

    s.min_players,

    s.max_players,

    s.stddev_players,

    s.coefficient_of_variation,

    s.activity_range_percent,

    t.first_players,

    t.latest_players,

    t.total_change,

    t.total_change_percent,

    t.trend,

    CASE
        WHEN s.observations < 28
            THEN 'Preliminary'

        WHEN s.coefficient_of_variation < 10
            THEN 'Stable'

        WHEN s.coefficient_of_variation < 25
            THEN 'Moderately volatile'

        WHEN s.coefficient_of_variation < 50
            THEN 'Volatile'

        ELSE 'Highly volatile'
    END AS activity_profile

FROM game_stability_analysis s

LEFT JOIN game_activity_trends t
    ON s.appid = t.appid;
-- 16. Десятка самых банимых героев.
-- bans — строки match_bans, picks — строки match_players, bans_per_pick =
-- round(bans::numeric / picks, 2); первые десять берутся после сортировки.
--
-- Колонки: hero, bans, picks, bans_per_pick
-- Порядок: bans по убыванию, при равенстве hero по возрастанию
-- Строк:   10

WITH bans AS (
    SELECT 
        hero_id,
        COUNT(DISTINCT match_bans.match_id) AS bans
    FROM match_bans
    GROUP BY hero_id
),
picks AS (
    SELECT 
        hero_id,
        COUNT(DISTINCT match_players.match_id) AS picks
    FROM match_players
    GROUP BY hero_id
)
SELECT
    h.name AS hero,
    b.bans,
    p.picks,
    ROUND(b.bans::numeric / p.picks, 2) AS bans_per_pick
FROM
    heroes AS h
    JOIN bans AS b ON b.hero_id = h.hero_id
    JOIN picks AS p ON p.hero_id = h.hero_id
ORDER BY
    bans DESC,
    hero ASC
LIMIT
    10;
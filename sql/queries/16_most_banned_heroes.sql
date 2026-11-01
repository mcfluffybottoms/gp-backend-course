-- 16. Десятка самых банимых героев.
-- bans — строки match_bans, picks — строки match_players, bans_per_pick =
-- round(bans::numeric / picks, 2); первые десять берутся после сортировки.
--
-- Колонки: hero, bans, picks, bans_per_pick
-- Порядок: bans по убыванию, при равенстве hero по возрастанию
-- Строк:   10

SELECT
    h.name AS hero,
    COUNT(DISTINCT mb.match_id) AS bans,
    COUNT(DISTINCT mp.match_id) AS picks,
    ROUND(COUNT(DISTINCT mb.match_id)::numeric / COUNT(DISTINCT mp.match_id), 2) AS bans_per_pick
FROM
    heroes AS h
    JOIN match_bans AS mb ON mb.hero_id = h.hero_id
    JOIN match_players AS mp ON mp.hero_id = h.hero_id
GROUP BY
    h.name
ORDER BY
    bans DESC,
    hero ASC
LIMIT
    10;
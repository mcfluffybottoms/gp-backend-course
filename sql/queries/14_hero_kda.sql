-- 14. Средние убийства, смерти и помощь у ходовых героев.
-- Только герои с games >= 420; средние — round(avg(x), 2) по numeric, два знака.
--
-- Колонки: hero, games, avg_kills, avg_deaths, avg_assists
-- Порядок: avg_kills (округлённое) по убыванию, при равенстве hero по возрастанию
-- Строк:   29
SELECT
    h.name AS hero,
    COUNT(*) AS games,
    ROUND(AVG(mp.kills :: numeric), 2) AS avg_kills,
    ROUND(AVG(mp.deaths :: numeric), 2) AS avg_deaths,
    ROUND(AVG(mp.assists :: numeric), 2) AS avg_assists
FROM
    heroes AS h
    JOIN match_players AS mp ON h.hero_id = mp.hero_id
GROUP BY
    h.hero_id,
    h.name
HAVING
    COUNT(*) >= 420
ORDER BY
    avg_kills DESC,
    hero ASC
LIMIT
    29;
-- 17. Доля побед светлой стороны по патчам.
-- Патч без единого матча не выводится; radiant_winrate — процент,
-- round(100.0 * radiant_wins / matches, 2).
--
-- Колонки: version, matches, radiant_wins, radiant_winrate
-- Порядок: radiant_winrate (округлённое) по убыванию, при равенстве version по возрастанию
-- Строк:   12

SELECT
    p.version,
    COUNT(DISTINCT m.match_id) AS matches,
    COUNT(*) FILTER (WHERE m.winner = 'radiant') AS radiant_wins,
    ROUND(100.0 * (COUNT(*) FILTER (WHERE m.winner = 'radiant'))  / COUNT(DISTINCT m.match_id), 2) AS radiant_winrate
FROM
    patches AS p
    JOIN matches AS m ON p.patch_id = m.patch_id
GROUP BY
    p.version
ORDER BY
    radiant_winrate DESC,
    version ASC;
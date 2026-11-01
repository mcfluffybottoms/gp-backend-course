-- 24. Турниры, чей призовой фонд больше суммы призовых всех предыдущих.
-- Предыдущие — со строго меньшим started_at, сравнение строгое; у первого турнира
-- prev_total и prev_count нули, не NULL; matches_played — число матчей турнира.
--
-- Колонки: tournament, started_at, prize_pool, prev_total, prev_count, matches_played
-- Порядок: started_at по возрастанию
-- Строк:   2

WITH prev AS (
    SELECT
        t.tournament_id,
        COALESCE((
            SELECT SUM(t2.prize_pool)
            FROM tournaments AS t2
            WHERE t2.started_at < t.started_at
        ), 0) AS prev_total,
        (
            SELECT COUNT(*)
            FROM tournaments AS t2
            WHERE t2.started_at < t.started_at
        ) AS prev_count
    FROM tournaments AS t
)
SELECT
    t.name AS tournament,
    t.started_at,
    t.prize_pool,
    prev.prev_total,
    prev.prev_count,
    (
        SELECT COUNT(*)
        FROM matches AS m
        WHERE m.tournament_id = t.tournament_id
    ) AS matches_played
FROM tournaments AS t
JOIN prev
    ON prev.tournament_id = t.tournament_id
WHERE t.prize_pool > prev.prev_total
ORDER BY
    t.started_at ASC
LIMIT 2;
-- 24. Турниры, чей призовой фонд больше суммы призовых всех предыдущих.
-- Предыдущие — со строго меньшим started_at, сравнение строгое; у первого турнира
-- prev_total и prev_count нули, не NULL; matches_played — число матчей турнира.
--
-- Колонки: tournament, started_at, prize_pool, prev_total, prev_count, matches_played
-- Порядок: started_at по возрастанию
-- Строк:   2

WITH history AS (
    SELECT
        tournament_id,
        name,
        started_at,
        prize_pool,
        COALESCE(SUM(prize_pool) OVER (
            ORDER BY started_at, tournament_id
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND 1 PRECEDING
        ), 0) AS prev_total,
        COUNT(prize_pool) OVER (
            ORDER BY started_at, tournament_id
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND 1 PRECEDING
        ) AS prev_count
    FROM tournaments
),
match_counts AS (
    SELECT 
        tournament_id,
        COUNT(*) AS matches_played
    FROM matches
    GROUP BY tournament_id
)
SELECT
    h.name AS tournament,
    h.started_at,
    h.prize_pool,
    h.prev_total,
    h.prev_count,
    mc.matches_played
FROM history AS h
LEFT JOIN match_counts  AS mc
    ON h.tournament_id = mc.tournament_id
WHERE h.prize_pool > h.prev_total
ORDER BY
    h.started_at ASC;
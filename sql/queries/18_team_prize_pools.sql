-- 18. Призовые турниров, до которых добрались игроки команды.
-- Турнир в зачёт один раз, если игрок сыграл его матч в составе: joined_at <=
-- started_at::date < left_at (пустой left_at — сейчас); команды без турниров не выводятся.
--
-- Колонки: team, tag, tournaments, prize_total
-- Порядок: prize_total по убыванию, при равенстве team по возрастанию
-- Строк:   22


WITH team_tournaments AS (
    SELECT DISTINCT
        tm.team_id,
        t.tournament_id,
        t.prize_pool
    FROM team_members tm
    JOIN match_players mp
        ON mp.player_id = tm.player_id
    JOIN matches m
        ON m.match_id = mp.match_id
    JOIN tournaments t
        ON t.tournament_id = m.tournament_id
    WHERE tm.joined_at <= m.started_at::date
      AND (
          tm.left_at IS NULL
          OR m.started_at::date < tm.left_at
      )
)
SELECT
    te.name AS team,
    te.tag,
    COUNT(*) AS tournaments,
    SUM(tt.prize_pool) AS prize_total
FROM teams AS te
JOIN team_tournaments AS tt
    ON tt.team_id = te.team_id
GROUP BY
    te.team_id,
    te.name,
    te.tag
ORDER BY
    prize_total DESC,
    team ASC;
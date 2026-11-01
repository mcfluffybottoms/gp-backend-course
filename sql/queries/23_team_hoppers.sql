-- 23. Игроки, поигравшие больше чем за одну команду.
-- Считаются различные team_id по всем периодам, строго больше одного; current_team —
-- название команды с пустым left_at, current_team и streamer могут быть NULL.
--
-- Колонки: player, country, teams_count, current_team, streamer
-- Порядок: teams_count по убыванию, при равенстве player по возрастанию
-- Строк:   25

WITH player_teams AS (
    SELECT
        player_id,
        COUNT(DISTINCT team_id) AS teams_count
    FROM team_members
    GROUP BY player_id
    HAVING COUNT(DISTINCT team_id) > 1
),
current_teams AS (
    SELECT
        tm.player_id,
        t.name AS current_team
    FROM team_members tm
    JOIN teams t
        ON t.team_id = tm.team_id
    WHERE tm.left_at IS NULL
)
SELECT
    p.nickname AS player,
    p.country AS country,
    pt.teams_count,
    ct.current_team,
    s.nickname AS streamer
FROM players AS p
JOIN player_teams AS pt
    ON pt.player_id = p.player_id
LEFT JOIN current_teams AS ct
    ON ct.player_id = p.player_id
LEFT JOIN streamers AS s
    ON s.player_id = p.player_id
ORDER BY
    teams_count DESC,
    player ASC
LIMIT 25;
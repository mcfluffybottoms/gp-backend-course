-- 22. Стримеры с подписчиками выше среднего по своей площадке.
-- Строго больше среднего по всем стримерам площадки, сам стример в среднее входит;
-- platform_avg до 2 знаков; team — тег действующей команды, иначе NULL.
--
-- Колонки: streamer, platform, followers, platform_avg, team
-- Порядок: followers по убыванию, при равенстве streamer по возрастанию
-- Строк:   16

WITH avg_f_count AS (
    SELECT
        s.platform_id,
        AVG(followers) AS platform_avg
    FROM streamers AS s
    GROUP BY
        s.platform_id
)
SELECT
    s.nickname AS streamer,
    plat.name AS platform,
    s.followers AS followers,
    avg.platform_avg,
    t.tag AS team
FROM streamers AS s
JOIN platforms AS plat
    ON plat.platform_id = s.platform_id
JOIN avg_f_count AS avg
    ON avg.platform_id = s.platform_id
LEFT JOIN team_members AS tm
    ON tm.player_id = s.player_id AND tm.left_at IS NULL
LEFT JOIN teams AS t
    ON tm.team_id = t.team_id
WHERE 
    s.followers > avg.platform_avg
ORDER BY
    followers DESC,
    streamer ASC
LIMIT 16;
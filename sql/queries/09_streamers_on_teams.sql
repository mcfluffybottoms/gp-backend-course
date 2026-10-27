-- 09. Кто из стримеров за какую команду выступает сейчас.
-- Только действующие составы; стримеры без player_id не выводятся.
--
-- Колонки: streamer, platform, player, team, tag, followers
-- Порядок: followers по убыванию, при равенстве streamer по возрастанию
-- Строк:   16
SELECT
    s.nickname AS streamer,
    pl.name AS platform,
    p.nickname AS player,
    t.name AS team,
    t.tag,
    s.followers
FROM
    streamers AS s
    JOIN platforms AS pl ON pl.platform_id = s.platform_id
    JOIN players AS p ON p.player_id = s.player_id
    JOIN team_members AS tm ON tm.player_id = p.player_id
    AND tm.left_at IS NULL
    JOIN teams AS t ON t.team_id = tm.team_id
ORDER BY
    followers DESC,
    streamer ASC
LIMIT
    16;
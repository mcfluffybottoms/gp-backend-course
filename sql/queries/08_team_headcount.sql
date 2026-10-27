-- 08. Сколько в команде игроков и сколько среди них стримеров.
-- Считаются только незакрытые периоды; команда без состава остаётся
-- в ответе с нулями, стримеры без player_id не учитываются.
--
-- Колонки: name, tag, players_now, streamers_now
-- Порядок: players_now по убыванию, при равенстве name по возрастанию
-- Строк:   24
SELECT
    t.name,
    t.tag,
    COUNT(DISTINCT tm.player_id) AS players_now,
    COUNT(DISTINCT s.player_id) AS streamers_now
FROM
    teams AS t
    LEFT JOIN team_members AS tm ON t.team_id = tm.team_id
    AND tm.left_at IS NULL
    LEFT JOIN streamers AS s ON s.player_id = tm.player_id
GROUP BY
    t.name,
    t.tag
ORDER BY
    players_now DESC,
    t.name ASC
LIMIT
    24;
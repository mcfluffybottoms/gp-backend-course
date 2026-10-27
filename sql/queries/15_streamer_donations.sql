-- 15. Сколько донатов собрал каждый стример.
-- В ответе все стримеры: без донатов donations = 0 и total_amount = 0.00;
-- team — команда с left_at IS NULL, иначе пусто.
--
-- Колонки: streamer, platform, team, donations, total_amount
-- Порядок: total_amount по убыванию, при равенстве streamer по возрастанию
-- Строк:   40
SELECT
    s.nickname AS streamer,
    p.name AS platform,
    t.name AS team,
    COUNT(sd.donation_id) AS donations,
    COALESCE(SUM(sd.amount), 0) :: numeric(12, 2) AS total_amount
FROM
    streamers AS s
    JOIN platforms AS p ON s.platform_id = p.platform_id
    LEFT JOIN team_members AS tm ON tm.player_id = s.player_id
    AND tm.left_at IS NULL
    LEFT JOIN teams AS t ON t.team_id = tm.team_id
    LEFT JOIN streams AS ss ON ss.streamer_id = s.streamer_id
    LEFT JOIN stream_donations AS sd ON ss.stream_id = sd.stream_id
GROUP BY
    p.name,
    t.name,
    s.nickname
ORDER BY
    total_amount DESC,
    streamer ASC
LIMIT
    40;
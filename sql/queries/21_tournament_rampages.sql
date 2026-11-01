-- 21. Турнирные выступления с KDA выше шестикратного среднего.
-- KDA = (kills + assists)::numeric / GREATEST(deaths, 1); порог — строго больше шести
-- средних KDA по всей match_players; только матчи турниров; kda округлить до 2 знаков.
--
-- Колонки: match_id, tournament, player, hero, kda
-- Порядок: kda по убыванию, при равенстве match_id, затем slot
-- Строк:   60

WITH avg_kda AS (
    SELECT
        AVG(
            (kills + assists)::numeric / GREATEST(deaths, 1)
        ) AS avg_value
    FROM match_players
),
stats AS (
    SELECT
        m.match_id,
        mp.slot,
        mp.player_id,
        mp.hero_id,
        mp.kills,
        mp.deaths,
        mp.assists,
        (mp.kills + mp.assists)::numeric / GREATEST(mp.deaths, 1) AS kda
    FROM matches m
    JOIN match_players mp
        ON mp.match_id = m.match_id
    WHERE m.tournament_id IS NOT NULL
)
SELECT
    ss.match_id,
    t.name AS tournament,
    pl.nickname AS player,
    h.name AS hero,
    ROUND(ss.kda, 2) AS kda
FROM stats AS ss
JOIN matches AS m
    ON m.match_id = ss.match_id
JOIN tournaments AS t
    ON t.tournament_id = m.tournament_id
JOIN players AS pl
    ON pl.player_id = ss.player_id
JOIN heroes AS h
    ON h.hero_id = ss.hero_id
CROSS JOIN avg_kda AS a
WHERE ss.kda > 6 * a.avg_value
ORDER BY
    ss.kda DESC,
    ss.match_id ASC,
    ss.slot ASC
LIMIT 60;
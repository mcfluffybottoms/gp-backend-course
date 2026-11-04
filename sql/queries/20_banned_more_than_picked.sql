-- 20. Герои, которых на патче банили чаще, чем брали.
-- Патч — matches.patch_id; в ответе пары с bans строго больше picks, diff = bans - picks.
--
-- Колонки: version, hero, bans, picks, diff
-- Порядок: diff по убыванию, затем hero по возрастанию, затем version по возрастанию
-- Строк:   99

WITH ban_counts AS (
    SELECT
        m.patch_id,
        mb.hero_id,
        COUNT(*) AS bans
    FROM match_bans AS mb
    JOIN matches AS m
        ON m.match_id = mb.match_id
    GROUP BY
        m.patch_id,
        mb.hero_id
),
pick_counts AS (
    SELECT
        m.patch_id,
        mp.hero_id,
        COUNT(*) AS picks
    FROM match_players mp
    JOIN matches m
        ON m.match_id = mp.match_id
    GROUP BY
        m.patch_id,
        mp.hero_id
)
SELECT
    p.version,
    h.name AS hero,
    b.bans,
    pk.picks,
    b.bans - pk.picks AS diff
FROM heroes AS h
JOIN ban_counts AS b
    ON h.hero_id = b.hero_id
LEFT JOIN pick_counts AS pk
    ON pk.patch_id = b.patch_id AND pk.hero_id = b.hero_id
JOIN patches AS p
    ON p.patch_id = b.patch_id
WHERE b.bans > pk.picks
ORDER BY
    diff DESC,
    hero ASC,
    version ASC;
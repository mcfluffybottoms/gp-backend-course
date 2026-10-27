-- 10. Все роли героев, которые умеют быть керри.
-- Только герои с ролью 'carry'; у каждого выводятся все его роли, по строке на роль.
--
-- Колонки: name, primary_attr, attack_type, role
-- Порядок: name по возрастанию, внутри героя role по возрастанию
-- Строк:   47
SELECT
    h.name AS name,
    h.primary_attr AS primary_attr,
    h.attack_type AS attack_type,
    hr.role AS role
FROM
    heroes AS h
    JOIN hero_roles AS hr ON hr.hero_id = h.hero_id
WHERE
    EXISTS (
        SELECT
            1
        FROM
            hero_roles AS hr2
        WHERE
            hr2.hero_id = h.hero_id
            AND hr2.role = 'carry'
    )
ORDER BY
    name ASC,
    role ASC
LIMIT
    47;
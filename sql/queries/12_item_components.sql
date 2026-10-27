-- 12. Сборные предметы внутри сборных предметов.
-- Пары «предмет — непосредственный компонент», где компонент сам встречается
-- в item_recipe.item_id; каждая пара один раз, component_cost — цена штуки.
--
-- Колонки: item_name, component_name, quantity, component_cost
-- Порядок: item_name по возрастанию, внутри предмета component_name по возрастанию
-- Строк:   36
SELECT
    i1.name AS item_name,
    i2.name AS component_name,
    ir.quantity AS quantity,
    i2.cost AS component_cost
FROM
    items AS i1
    JOIN item_recipe AS ir ON ir.item_id = i1.item_id
    JOIN items AS i2 ON ir.component_id = i2.item_id
WHERE
    EXISTS (
        SELECT
            1
        FROM
            item_recipe AS ir2
        WHERE
            ir2.item_id = i2.item_id
    )
ORDER BY
    item_name ASC,
    component_name ASC
LIMIT
    36;
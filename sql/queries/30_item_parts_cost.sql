-- 30. Стоимость сборки из базовых составляющих против собственной цены предмета.
-- Берутся предметы со строками в item_recipe, сборка раскрывается до базовых (тех, у кого
-- строк в item_recipe нет, свитки тоже), количества по пути перемножаются; diff = parts_cost - cost.
--
-- Колонки: name, cost, parts_cost, base_parts, diff
-- Порядок: diff по убыванию, при равенстве name по возрастанию
-- Строк:   77

WITH RECURSIVE assembly AS (
    SELECT
        root.item_id AS root_id,
        root.name AS name,
        root.cost,
        ir.component_id,
        ir.quantity::bigint AS qty_total
    FROM items AS root
    JOIN item_recipe AS ir
        ON ir.item_id = root.item_id

    UNION ALL
    SELECT
        a.root_id,
        a.name,
        a.cost,
        ir.component_id,
        a.qty_total * ir.quantity AS qty_total
    FROM assembly AS a
    JOIN item_recipe AS ir
        ON ir.item_id = a.component_id
),
base_components AS (
    SELECT
        a.root_id,
        a.name,
        a.cost,
        a.component_id,
        a.qty_total,
        component.cost AS component_cost
    FROM assembly AS a
    JOIN items AS component
        ON component.item_id = a.component_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM item_recipe AS ir
        WHERE ir.item_id = a.component_id
    )
),
parts_totals AS (
    SELECT
        root_id,
        SUM(component_cost::bigint * qty_total) AS parts_cost,
        SUM(qty_total) AS base_parts
    FROM base_components
    GROUP BY root_id
)
SELECT
    i.name,
    i.cost,
    pt.parts_cost,
    pt.base_parts,
    pt.parts_cost - i.cost AS diff
FROM parts_totals AS pt
JOIN items AS i
    ON i.item_id = pt.root_id
ORDER BY
    diff DESC,
    name ASC;
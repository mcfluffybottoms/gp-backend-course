-- 29. Полное дерево сборки Guardian Greaves, Bloodthorn, Harpoon и Hurricane Pike.
-- Строка на каждый путь вниз, сам корень не выводится; lvl с 1, qty — quantity последнего
-- шага, qty_total — произведение quantity по пути, path — имена от корня через ' > '.
--
-- Колонки: root_item, lvl, component, qty, qty_total, path
-- Порядок: root_item по возрастанию, затем path по возрастанию
-- Строк:   34

WITH RECURSIVE item_tree AS (
    SELECT
        i.item_id AS root_id,
        i.name AS root_item,
        ir.component_id,
        c.name AS component,
        ir.quantity AS qty,
        ir.quantity AS qty_total,
        1 AS lvl,
        i.name || ' > ' || c.name AS path
    FROM items AS i
    JOIN item_recipe AS ir
        ON ir.item_id = i.item_id
    JOIN items AS c
        ON c.item_id = ir.component_id
    WHERE i.name IN (
        'Guardian Greaves',
        'Bloodthorn',
        'Harpoon',
        'Hurricane Pike'
    )

    UNION ALL

    SELECT
        it.root_id,
        it.root_item,
        ir.component_id,
        c.name AS component,
        ir.quantity AS qty,
        it.qty_total * ir.quantity AS qty_total,
        it.lvl + 1 AS lvl,
        it.path || ' > ' || c.name AS path
    FROM item_tree AS it
    JOIN item_recipe AS ir
        ON ir.item_id = it.component_id
    JOIN items AS c
        ON c.item_id = ir.component_id
)
SELECT
    root_item,
    lvl,
    component,
    qty,
    qty_total,
    path
FROM item_tree
ORDER BY root_item ASC, path ASC;
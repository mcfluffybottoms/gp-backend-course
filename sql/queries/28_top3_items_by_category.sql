-- 28. Три самых дорогих предмета в каждой категории лавки.
-- Категория: 'recipe' при is_recipe, иначе 'assembled' при строках в item_recipe.item_id,
-- иначе 'basic'; place 1-3 по cost убыв., при равной цене по name; purchases — строк match_items, иначе 0.
--
-- Колонки: category, place, name, cost, purchases
-- Порядок: category по возрастанию, затем place по возрастанию
-- Строк:   9

WITH item_categories AS (
    SELECT
        i.item_id,
        i.name,
        i.cost,
        CASE
            WHEN i.is_recipe THEN 'recipe'
            WHEN EXISTS (
                SELECT 1
                FROM item_recipe ir
                WHERE ir.item_id = i.item_id
            ) THEN 'assembled'
            ELSE 'basic'
        END AS category
    FROM items i
),
item_purchases AS (
    SELECT
        item_id,
        COUNT(*) AS purchases
    FROM match_items
    GROUP BY item_id
),
ranked_items AS (
    SELECT
        ic.category,
        ic.name,
        ic.cost,
        COALESCE(ip.purchases, 0) AS purchases,
        ROW_NUMBER() OVER (
            PARTITION BY ic.category
            ORDER BY ic.cost DESC, ic.name ASC
        ) AS place
    FROM item_categories AS ic
    LEFT JOIN item_purchases AS ip
        ON ip.item_id = ic.item_id
)
SELECT
    category,
    place,
    name,
    cost,
    purchases
FROM ranked_items
WHERE place <= 3
ORDER BY
    category ASC,
    place ASC;
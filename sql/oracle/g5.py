"""Группа 5, задачи 25-30: оконные функции и рекурсивные запросы.

Ответ каждой задачи считается здесь заново, на чистом Python, по исходным
таблицам из harness.table(). Ни одного SQL-запроса в этом файле нет и быть
не должно: иначе проверка сведётся к сравнению запроса с самим собой.
Окна и рекурсия написаны руками — словарями, списками и обходом в глубину.

База поднята с локалью C, поэтому текст в ней сравнивается побайтово —
ровно так же, как сравнивает строки Python, и возня с collation не нужна.
"""
import datetime
import decimal

from task import Task
import harness


UTC = datetime.timezone.utc


# ---------------------------------------------------------------------
# 25. Место стримера-профессионала в рейтинге своей страны
# ---------------------------------------------------------------------

def expected_25():
    players = harness.table("players")

    # Разбиение по стране: оконная функция, выписанная руками.
    by_country = {}
    for p in players:
        by_country.setdefault(p["country"], []).append(p)

    country_rank = {}      # player_id -> место по mmr внутри страны
    country_players = {}   # country   -> сколько всего игроков в стране
    for country, group in by_country.items():
        country_players[country] = len(group)
        for p in group:
            # RANK: место = число земляков со строго большим mmr плюс один.
            higher = sum(1 for other in group if other["mmr"] > p["mmr"])
            country_rank[p["player_id"]] = higher + 1

    platform_name = {pl["platform_id"]: pl["name"]
                     for pl in harness.table("platforms")}
    team_tag = {t["team_id"]: t["tag"] for t in harness.table("teams")}

    # Действующая команда: строка team_members с пустым left_at.
    # В данных такая строка у каждого игрока не больше одной.
    current_team = {}
    for tm in harness.table("team_members"):
        if tm["left_at"] is None:
            current_team[tm["player_id"]] = tm["team_id"]

    player_by_id = {p["player_id"]: p for p in players}

    rows = []
    for s in harness.table("streamers"):
        pid = s["player_id"]
        if pid is None or pid not in current_team:
            continue
        p = player_by_id[pid]
        rows.append((
            p["nickname"],
            p["country"],
            p["mmr"],
            country_rank[pid],
            country_players[p["country"]],
            team_tag[current_team[pid]],
            platform_name[s["platform_id"]],
        ))

    # Порядок: страна по возрастанию, внутри страны — место по возрастанию.
    rows.sort(key=lambda r: (r[1], r[3]))
    return rows


# ---------------------------------------------------------------------
# 26. Нарастающая сумма донатов на стримах Вжлинка за 2021 год
# ---------------------------------------------------------------------

def expected_26():
    streamer_id = next(s["streamer_id"] for s in harness.table("streamers")
                       if s["nickname"] == "Вжлинк")

    year_start = datetime.datetime(2021, 1, 1, tzinfo=UTC)
    year_end = datetime.datetime(2022, 1, 1, tzinfo=UTC)
    streams = {s["stream_id"]: s for s in harness.table("streams")
               if s["streamer_id"] == streamer_id
               and year_start <= s["started_at"] < year_end}

    by_stream = {}
    for d in harness.table("stream_donations"):
        if d["stream_id"] in streams:
            by_stream.setdefault(d["stream_id"], []).append(d)

    rows = []
    for stream_id in sorted(by_stream):
        # Нарастающий итог внутри стрима: суммируем в порядке времени доната.
        total = decimal.Decimal("0.00")
        donations = sorted(by_stream[stream_id],
                           key=lambda d: (d["sent_at_sec"], d["donation_id"]))
        for d in donations:
            total += d["amount"]
            rows.append((stream_id, streams[stream_id]["title"], d["sent_at_sec"],
                         d["nickname"], d["amount"], total))
    return rows


# ---------------------------------------------------------------------
# 27. Пик онлайна против пика предыдущего эфира того же стримера
# ---------------------------------------------------------------------

def expected_27():
    platform_id = next(p["platform_id"] for p in harness.table("platforms")
                       if p["name"] == "VK Play Live")
    streamers = {s["streamer_id"]: s for s in harness.table("streamers")
                 if s["platform_id"] == platform_id}

    by_streamer = {}
    for s in harness.table("streams"):
        if s["streamer_id"] in streamers:
            by_streamer.setdefault(s["streamer_id"], []).append(s)

    rows = []
    for streamer_id, streams in by_streamer.items():
        st = streamers[streamer_id]
        streams.sort(key=lambda s: s["started_at"])
        prev_peak = None
        for s in streams:
            # Первый эфир стримера сравнивать не с чем — такой строки в ответе нет.
            if prev_peak is not None:
                rows.append((st["nickname"], st["followers"], s["started_at"],
                             s["title"], s["peak_viewers"], prev_peak,
                             s["peak_viewers"] - prev_peak))
            prev_peak = s["peak_viewers"]

    # Порядок: подписчики по убыванию, внутри стримера — время по возрастанию.
    rows.sort(key=lambda r: (-r[1], r[2]))
    return rows


# ---------------------------------------------------------------------
# 28. Три самых дорогих предмета в каждой категории лавки
# ---------------------------------------------------------------------

def expected_28():
    assembled = {r["item_id"] for r in harness.table("item_recipe")}

    purchases = {}
    for mi in harness.table("match_items"):
        purchases[mi["item_id"]] = purchases.get(mi["item_id"], 0) + 1

    buckets = {}
    for i in harness.table("items"):
        if i["is_recipe"]:
            category = "recipe"
        elif i["item_id"] in assembled:
            category = "assembled"
        else:
            category = "basic"
        buckets.setdefault(category, []).append(i)

    rows = []
    for category in sorted(buckets):
        # ROW_NUMBER внутри категории: дороже — раньше, при равной цене — по имени.
        items = sorted(buckets[category], key=lambda i: (-i["cost"], i["name"]))
        for place, i in enumerate(items[:3], start=1):
            rows.append((category, place, i["name"], i["cost"],
                         purchases.get(i["item_id"], 0)))
    return rows


# ---------------------------------------------------------------------
# 29. Полное дерево сборки предмета
# ---------------------------------------------------------------------

TREE_ROOTS = ("Guardian Greaves", "Bloodthorn", "Harpoon", "Hurricane Pike")


def _recipe_children():
    """item_id -> список (component_id, quantity)."""
    children = {}
    for r in harness.table("item_recipe"):
        children.setdefault(r["item_id"], []).append((r["component_id"], r["quantity"]))
    return children


def expected_29():
    items = {i["item_id"]: i for i in harness.table("items")}
    children = _recipe_children()

    rows = []

    def walk(node_id, lvl, qty_total, path, root_item):
        """Обход в глубину — то же, что делает рекурсивная часть WITH RECURSIVE."""
        for component_id, qty in children.get(node_id, []):
            name = items[component_id]["name"]
            child_path = path + " > " + name
            rows.append((root_item, lvl, name, qty, qty_total * qty, child_path))
            walk(component_id, lvl + 1, qty_total * qty, child_path, root_item)

    for item in items.values():
        if item["name"] in TREE_ROOTS:
            walk(item["item_id"], 1, 1, item["name"], item["name"])

    rows.sort(key=lambda r: (r[0], r[5]))
    return rows


# ---------------------------------------------------------------------
# 30. Стоимость сборки предмета из базовых составляющих против его цены
# ---------------------------------------------------------------------

def expected_30():
    items = {i["item_id"]: i for i in harness.table("items")}
    children = _recipe_children()

    def leaves(node_id, multiplier, out):
        """Спуск до предметов, которые сами ни из чего не собираются."""
        for component_id, qty in children.get(node_id, []):
            total = multiplier * qty
            if component_id in children:
                leaves(component_id, total, out)
            else:
                out.append((component_id, total))

    rows = []
    for item_id in children:
        collected = []
        leaves(item_id, 1, collected)
        parts_cost = sum(items[c]["cost"] * q for c, q in collected)
        base_parts = sum(q for _, q in collected)
        item = items[item_id]
        rows.append((item["name"], item["cost"], parts_cost, base_parts,
                     parts_cost - item["cost"]))

    # Порядок: diff по убыванию, при равенстве — название по возрастанию.
    rows.sort(key=lambda r: (-r[4], r[0]))
    return rows


TASKS = [
    Task(number=25, filename="25_streamer_country_rank.sql",
         title="Место стримера-профессионала в рейтинге своей страны",
         columns=["player", "country", "mmr", "country_rank", "country_players",
                  "team_tag", "platform"],
         ordered=True, expected=expected_25),
    Task(number=26, filename="26_vjlink_running_donations.sql",
         title="Нарастающая сумма донатов на стримах Вжлинка за 2021 год",
         columns=["stream_id", "title", "sent_at_sec", "donor", "amount",
                  "running_total"],
         ordered=True, expected=expected_26),
    Task(number=27, filename="27_vkplay_prev_peak.sql",
         title="Пик онлайна против пика предыдущего эфира: VK Play Live",
         columns=["streamer", "followers", "started_at", "title", "peak_viewers",
                  "prev_peak", "delta"],
         ordered=True, expected=expected_27),
    Task(number=28, filename="28_top3_items_by_category.sql",
         title="Три самых дорогих предмета в каждой категории лавки",
         columns=["category", "place", "name", "cost", "purchases"],
         ordered=True, expected=expected_28),
    Task(number=29, filename="29_item_component_tree.sql",
         title="Полное дерево сборки предмета",
         columns=["root_item", "lvl", "component", "qty", "qty_total", "path"],
         ordered=True, expected=expected_29),
    Task(number=30, filename="30_item_parts_cost.sql",
         title="Стоимость сборки из базовых частей против цены предмета",
         columns=["name", "cost", "parts_cost", "base_parts", "diff"],
         ordered=True, expected=expected_30),
]

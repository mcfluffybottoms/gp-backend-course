"""Группа 1, задачи 01-06: выборка, условия, сортировка.

Ответ каждой задачи считается здесь заново, на чистом Python, по исходным
таблицам из harness.table(). Ни одного SQL-запроса в этом файле нет и быть
не должно: иначе проверка сведётся к сравнению запроса с самим собой.

Сортировки написаны так же, как их задаёт условие. База поднята с локалью C,
поэтому текст в ней сравнивается побайтово — ровно так же, как сравнивает
строки Python, и отдельная возня с collation не нужна.
"""
from task import Task
import harness


# ---------------------------------------------------------------------
# 01. Герои ближнего боя с основным атрибутом «сила»
# ---------------------------------------------------------------------

def expected_01():
    rows = [h for h in harness.table("heroes")
            if h["primary_attr"] == "str" and h["attack_type"] == "melee"]
    rows.sort(key=lambda h: h["name"])
    return [(h["hero_id"], h["name"], h["legs"]) for h in rows]


# ---------------------------------------------------------------------
# 02. Пятнадцать самых высокорейтинговых игроков выше 9000
# ---------------------------------------------------------------------

def expected_02():
    rows = [p for p in harness.table("players") if p["mmr"] > 9000]
    # По убыванию рейтинга, при равенстве — по нику по возрастанию.
    rows.sort(key=lambda p: (-p["mmr"], p["nickname"]))
    return [(p["nickname"], p["country"], p["mmr"]) for p in rows[:15]]


# ---------------------------------------------------------------------
# 03. Страны, из которых есть игроки с рейтингом не ниже 10000
# ---------------------------------------------------------------------

def expected_03():
    countries = set()
    for p in harness.table("players"):
        if p["mmr"] >= 10000:
            countries.add(p["country"])
    return [(c,) for c in sorted(countries)]


# ---------------------------------------------------------------------
# 04. Матчи 2024 года длиннее часа
# ---------------------------------------------------------------------

def expected_04():
    rows = []
    for m in harness.table("matches"):
        # started_at приходит с зоной UTC, поэтому .year — это год по UTC.
        if m["started_at"].year == 2024 and m["duration_sec"] > 3600:
            rows.append(m)
    rows.sort(key=lambda m: m["started_at"])
    return [(m["match_id"], m["started_at"], m["duration_sec"], m["winner"])
            for m in rows]


# ---------------------------------------------------------------------
# 05. Герои с необычным числом ног
# ---------------------------------------------------------------------

def expected_05():
    rows = [h for h in harness.table("heroes") if h["legs"] != 2]
    rows.sort(key=lambda h: (-h["legs"], h["name"]))
    return [(h["name"], h["primary_attr"], h["attack_type"], h["legs"])
            for h in rows]


# ---------------------------------------------------------------------
# 06. Предметы средней ценовой полки, не считая свитков рецептов
# ---------------------------------------------------------------------

def expected_06():
    rows = [i for i in harness.table("items")
            if not i["is_recipe"] and 2000 <= i["cost"] <= 3000]
    rows.sort(key=lambda i: (-i["cost"], i["name"]))
    return [(i["name"], i["cost"]) for i in rows]


TASKS = [
    Task(number=1, filename="01_melee_strength.sql",
         title="Герои ближнего боя с основным атрибутом «сила»",
         columns=["hero_id", "name", "legs"], ordered=True,
         expected=expected_01),
    Task(number=2, filename="02_top_mmr.sql",
         title="Пятнадцать самых высокорейтинговых игроков выше 9000",
         columns=["nickname", "country", "mmr"], ordered=True,
         expected=expected_02),
    Task(number=3, filename="03_pro_countries.sql",
         title="Страны, из которых есть игроки с рейтингом не ниже 10000",
         columns=["country"], ordered=True,
         expected=expected_03),
    Task(number=4, filename="04_long_matches_2024.sql",
         title="Матчи 2024 года, продлившиеся дольше часа",
         columns=["match_id", "started_at", "duration_sec", "winner"],
         ordered=True, expected=expected_04),
    Task(number=5, filename="05_unusual_legs.sql",
         title="Герои с необычным числом ног",
         columns=["name", "primary_attr", "attack_type", "legs"], ordered=True,
         expected=expected_05),
    Task(number=6, filename="06_items_price_range.sql",
         title="Предметы от 2000 до 3000 золота, кроме свитков рецептов",
         columns=["name", "cost"], ordered=True,
         expected=expected_06),
]

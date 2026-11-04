"""Группа 2, задачи 07-12: соединения.

Ответы считаются на чистом Python по исходным таблицам, которые отдаёт
harness.table(): соединения собираются вручную через словари, группировки —
через накопители, сортировки — через list.sort. Никакого SQL здесь нет
и быть не должно: тест сверяет запрос студента именно с этим расчётом,
а повторение того же запроса лишило бы проверку смысла.
"""
from task import Task
import harness


# ---------------------------------------------------------------------
# 07. Действующие составы: кто сейчас за кого играет
# ---------------------------------------------------------------------

def expected_07():
    players = {p["player_id"]: p for p in harness.table("players")}
    teams = {t["team_id"]: t for t in harness.table("teams")}

    rows = []
    for m in harness.table("team_members"):
        if m["left_at"] is not None:        # период закрыт — игрок ушёл
            continue
        p = players[m["player_id"]]
        t = teams[m["team_id"]]
        rows.append((p["nickname"], p["country"], p["mmr"],
                     t["name"], m["joined_at"]))

    rows.sort(key=lambda r: (r[4], r[0]))   # joined_at, затем nickname
    return rows


# ---------------------------------------------------------------------
# 08. Сколько в команде игроков и сколько среди них стримеров
# ---------------------------------------------------------------------

def expected_08():
    streaming_players = {s["player_id"] for s in harness.table("streamers")
                         if s["player_id"] is not None}

    # team_id -> [игроков сейчас, из них стримеров]
    counts = {}
    for m in harness.table("team_members"):
        if m["left_at"] is not None:
            continue
        cell = counts.setdefault(m["team_id"], [0, 0])
        cell[0] += 1
        if m["player_id"] in streaming_players:
            cell[1] += 1

    rows = []
    for t in harness.table("teams"):        # все команды, даже пустые
        players_now, streamers_now = counts.get(t["team_id"], (0, 0))
        rows.append((t["name"], t["tag"], players_now, streamers_now))

    rows.sort(key=lambda r: (-r[2], r[0]))  # players_now по убыванию, name
    return rows


# ---------------------------------------------------------------------
# 09. Кто из стримеров за какую команду выступает сейчас
# ---------------------------------------------------------------------

def expected_09():
    platform_name = {p["platform_id"]: p["name"]
                     for p in harness.table("platforms")}
    players = {p["player_id"]: p for p in harness.table("players")}
    teams = {t["team_id"]: t for t in harness.table("teams")}

    # player_id -> команды, в которых он состоит сейчас
    current_teams = {}
    for m in harness.table("team_members"):
        if m["left_at"] is None:
            current_teams.setdefault(m["player_id"], []).append(m["team_id"])

    rows = []
    for s in harness.table("streamers"):
        if s["player_id"] is None:          # стример, который сам не играет
            continue
        player = players[s["player_id"]]
        for team_id in current_teams.get(s["player_id"], []):
            team = teams[team_id]
            rows.append((s["nickname"], platform_name[s["platform_id"]],
                         player["nickname"], team["name"], team["tag"],
                         s["followers"]))

    rows.sort(key=lambda r: (-r[5], r[0]))  # followers по убыванию, streamer
    return rows


# ---------------------------------------------------------------------
# 10. Все роли героев, которые умеют быть керри
# ---------------------------------------------------------------------

def expected_10():
    heroes = {h["hero_id"]: h for h in harness.table("heroes")}
    hero_roles = harness.table("hero_roles")

    carries = {r["hero_id"] for r in hero_roles if r["role"] == "carry"}

    rows = []
    for r in hero_roles:
        if r["hero_id"] not in carries:
            continue
        h = heroes[r["hero_id"]]
        rows.append((h["name"], h["primary_attr"], h["attack_type"], r["role"]))

    rows.sort(key=lambda r: (r[0], r[3]))   # name, затем role
    return rows


# ---------------------------------------------------------------------
# 11. Самые затяжные матчи и турниры, на которых они сыграны
# ---------------------------------------------------------------------

def expected_11():
    tournament_name = {t["tournament_id"]: t["name"]
                       for t in harness.table("tournaments")}

    rows = []
    for m in harness.table("matches"):
        if m["duration_sec"] < 4700:
            continue
        # started_at приходит со смещением +00, поэтому .date() — дата по UTC
        name = (None if m["tournament_id"] is None
                else tournament_name[m["tournament_id"]])
        rows.append((m["match_id"], m["started_at"].date(),
                     m["duration_sec"], name))

    rows.sort(key=lambda r: (-r[2], r[0]))  # duration_sec по убыванию, match_id
    return rows


# ---------------------------------------------------------------------
# 12. Сборные предметы внутри сборных предметов
# ---------------------------------------------------------------------

def expected_12():
    items = {i["item_id"]: i for i in harness.table("items")}
    recipe = harness.table("item_recipe")

    assembled = {r["item_id"] for r in recipe}   # у кого есть свой рецепт

    rows = []
    for r in recipe:
        if r["component_id"] not in assembled:
            continue
        item = items[r["item_id"]]
        component = items[r["component_id"]]
        rows.append((item["name"], component["name"],
                     r["quantity"], component["cost"]))

    rows.sort(key=lambda r: (r[0], r[1]))   # item_name, затем component_name
    return rows


TASKS = [
    Task(number=7, filename="07_current_rosters.sql",
         title="Действующие составы: кто сейчас за кого играет",
         columns=["nickname", "country", "mmr", "team_name", "joined_at"],
         ordered=True, expected=expected_07),
    Task(number=8, filename="08_team_headcount.sql",
         title="Сколько в команде игроков и сколько среди них стримеров",
         columns=["name", "tag", "players_now", "streamers_now"],
         ordered=True, expected=expected_08),
    Task(number=9, filename="09_streamers_on_teams.sql",
         title="Кто из стримеров за какую команду выступает сейчас",
         columns=["streamer", "platform", "player", "team", "tag", "followers"],
         ordered=True, expected=expected_09),
    Task(number=10, filename="10_carry_heroes_roles.sql",
         title="Все роли героев, которые умеют быть керри",
         columns=["name", "primary_attr", "attack_type", "role"],
         ordered=True, expected=expected_10),
    Task(number=11, filename="11_longest_matches.sql",
         title="Самые затяжные матчи и турниры, на которых они сыграны",
         columns=["match_id", "match_date", "duration_sec", "tournament_name"],
         ordered=True, expected=expected_11),
    Task(number=12, filename="12_item_components.sql",
         title="Сборные предметы внутри сборных предметов",
         columns=["item_name", "component_name", "quantity", "component_cost"],
         ordered=True, expected=expected_12),
]

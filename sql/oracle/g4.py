"""Группа 4, задачи 19-24: подзапросы и обобщённые табличные выражения.

Ответы считаются на чистом Python по исходным таблицам, которые отдаёт
harness.table(): соединения собираются вручную через словари, подсчёты —
через накопители, сортировки — через list.sort. Никакого SQL здесь нет
и быть не должно: тест сверяет запрос студента именно с этим расчётом,
а повторение того же запроса лишило бы проверку смысла.

Дробные значения считаются в decimal.Decimal и округляются до двух
знаков с половиной ВВЕРХ — так же, как round(numeric, 2) в PostgreSQL.
Сортировка строк идёт обычным сравнением строк Python: оно побайтово
совпадает с локалью C, в которой инициализирована база.
"""
import decimal

from task import Task
import harness

TWO = decimal.Decimal("0.01")


def round2(value):
    """Округление до двух знаков, половина вверх — как round(numeric, 2)."""
    return value.quantize(TWO, rounding=decimal.ROUND_HALF_UP)


def current_team_of_player():
    """player_id -> строка teams, в которой игрок состоит сейчас (left_at пуст)."""
    teams = {t["team_id"]: t for t in harness.table("teams")}
    current = {}
    for m in harness.table("team_members"):
        if m["left_at"] is None:
            current[m["player_id"]] = teams[m["team_id"]]
    return current


# ---------------------------------------------------------------------
# 19. Стримеры, которые ни разу не брали Pudge
# ---------------------------------------------------------------------

def expected_19():
    platform_name = {p["platform_id"]: p["name"]
                     for p in harness.table("platforms")}
    pudge_id = next(h["hero_id"] for h in harness.table("heroes")
                    if h["name"] == "Pudge")

    games = {}            # player_id -> сколько матчей сыграл
    with_pudge = set()    # player_id тех, кто брал Pudge хотя бы раз
    for mp in harness.table("match_players"):
        games[mp["player_id"]] = games.get(mp["player_id"], 0) + 1
        if mp["hero_id"] == pudge_id:
            with_pudge.add(mp["player_id"])

    current = current_team_of_player()

    rows = []
    for s in harness.table("streamers"):
        player_id = s["player_id"]
        if player_id is None:        # стример, который сам не играет
            continue
        if player_id in with_pudge:  # именно это и отсекает NOT EXISTS
            continue
        team = current.get(player_id)
        rows.append((s["nickname"],
                     platform_name[s["platform_id"]],
                     team["tag"] if team else None,
                     s["followers"],
                     games.get(player_id, 0)))

    rows.sort(key=lambda r: (-r[3], r[0]))   # followers по убыванию, streamer
    return rows


# ---------------------------------------------------------------------
# 20. Герои, которых на патче банили чаще, чем брали
# ---------------------------------------------------------------------

def expected_20():
    patch_of_match = {m["match_id"]: m["patch_id"]
                      for m in harness.table("matches")}
    version = {p["patch_id"]: p["version"] for p in harness.table("patches")}
    hero_name = {h["hero_id"]: h["name"] for h in harness.table("heroes")}

    bans = {}    # (patch_id, hero_id) -> сколько раз забанен
    for b in harness.table("match_bans"):
        key = (patch_of_match[b["match_id"]], b["hero_id"])
        bans[key] = bans.get(key, 0) + 1

    picks = {}   # (patch_id, hero_id) -> сколько раз взят
    for mp in harness.table("match_players"):
        key = (patch_of_match[mp["match_id"]], mp["hero_id"])
        picks[key] = picks.get(key, 0) + 1

    # Пары без банов до ответа всё равно не доживут: ноль банов больше
    # числа пиков быть не может, поэтому хватает обхода банов.
    rows = []
    for (patch_id, hero_id), ban_count in bans.items():
        pick_count = picks.get((patch_id, hero_id), 0)
        if ban_count > pick_count:
            rows.append((version[patch_id], hero_name[hero_id],
                         ban_count, pick_count, ban_count - pick_count))

    rows.sort(key=lambda r: (-r[4], r[1], r[0]))   # diff, hero, version
    return rows


# ---------------------------------------------------------------------
# 21. Разгромные выступления на турнирах
# ---------------------------------------------------------------------

def _kda(row):
    return decimal.Decimal(row["kills"] + row["assists"]) \
        / decimal.Decimal(max(row["deaths"], 1))


def expected_21():
    match_players = harness.table("match_players")

    # Порог: шесть средних KDA по всем участиям, турнирным и нет.
    total = decimal.Decimal(0)
    for mp in match_players:
        total += _kda(mp)
    threshold = 6 * (total / decimal.Decimal(len(match_players)))

    tournament_of_match = {m["match_id"]: m["tournament_id"]
                           for m in harness.table("matches")}
    tournament_name = {t["tournament_id"]: t["name"]
                       for t in harness.table("tournaments")}
    player_name = {p["player_id"]: p["nickname"]
                   for p in harness.table("players")}
    hero_name = {h["hero_id"]: h["name"] for h in harness.table("heroes")}

    rows = []
    for mp in match_players:
        tournament_id = tournament_of_match[mp["match_id"]]
        if tournament_id is None:        # матч вне турнира
            continue
        value = _kda(mp)
        if value <= threshold:
            continue
        rows.append((mp["match_id"], tournament_name[tournament_id],
                     player_name[mp["player_id"]], hero_name[mp["hero_id"]],
                     round2(value), mp["slot"]))

    # kda по убыванию, затем match_id, затем slot; slot в ответ не идёт.
    rows.sort(key=lambda r: (-r[4], r[0], r[5]))
    return [r[:5] for r in rows]


# ---------------------------------------------------------------------
# 22. Стримеры крупнее среднего по своей площадке
# ---------------------------------------------------------------------

def expected_22():
    streamers = harness.table("streamers")
    platform_name = {p["platform_id"]: p["name"]
                     for p in harness.table("platforms")}

    totals = {}   # platform_id -> [сумма подписчиков, число стримеров]
    for s in streamers:
        cell = totals.setdefault(s["platform_id"], [0, 0])
        cell[0] += s["followers"]
        cell[1] += 1
    averages = {platform_id: decimal.Decimal(total) / decimal.Decimal(count)
                for platform_id, (total, count) in totals.items()}

    current = current_team_of_player()

    rows = []
    for s in streamers:
        average = averages[s["platform_id"]]
        if decimal.Decimal(s["followers"]) <= average:   # сравнение строгое
            continue
        team = current.get(s["player_id"]) if s["player_id"] is not None else None
        rows.append((s["nickname"], platform_name[s["platform_id"]],
                     s["followers"], round2(average),
                     team["tag"] if team else None))

    rows.sort(key=lambda r: (-r[2], r[0]))   # followers по убыванию, streamer
    return rows


# ---------------------------------------------------------------------
# 23. Игроки, сменившие больше одной команды
# ---------------------------------------------------------------------

def expected_23():
    players = {p["player_id"]: p for p in harness.table("players")}
    streamer_of_player = {s["player_id"]: s["nickname"]
                          for s in harness.table("streamers")
                          if s["player_id"] is not None}

    all_teams = {}    # player_id -> множество команд за всю историю
    for m in harness.table("team_members"):
        all_teams.setdefault(m["player_id"], set()).add(m["team_id"])

    current = current_team_of_player()

    rows = []
    for player_id, team_ids in all_teams.items():
        if len(team_ids) <= 1:        # возвращение в тот же клуб не считается
            continue
        player = players[player_id]
        team = current.get(player_id)
        rows.append((player["nickname"], player["country"], len(team_ids),
                     team["name"] if team else None,
                     streamer_of_player.get(player_id)))

    rows.sort(key=lambda r: (-r[2], r[0]))   # teams_count по убыванию, player
    return rows


# ---------------------------------------------------------------------
# 24. Турниры, обогнавшие всю предыдущую историю
# ---------------------------------------------------------------------

def expected_24():
    tournaments = harness.table("tournaments")

    matches_played = {}   # tournament_id -> сколько матчей сыграно
    for m in harness.table("matches"):
        if m["tournament_id"] is not None:
            matches_played[m["tournament_id"]] = \
                matches_played.get(m["tournament_id"], 0) + 1

    rows = []
    for t in tournaments:
        previous = [x for x in tournaments if x["started_at"] < t["started_at"]]
        previous_total = sum(x["prize_pool"] for x in previous)   # пусто -> 0
        if t["prize_pool"] <= previous_total:
            continue
        rows.append((t["name"], t["started_at"], t["prize_pool"],
                     previous_total, len(previous),
                     matches_played.get(t["tournament_id"], 0)))

    rows.sort(key=lambda r: r[1])   # по дате старта, даты различны
    return rows


TASKS = [
    Task(number=19, filename="19_streamers_without_pudge.sql",
         title="Стримеры, которые ни разу не брали Pudge",
         columns=["streamer", "platform", "team", "followers", "games"],
         ordered=True, expected=expected_19),
    Task(number=20, filename="20_banned_more_than_picked.sql",
         title="Герои, которых на патче банили чаще, чем брали",
         columns=["version", "hero", "bans", "picks", "diff"],
         ordered=True, expected=expected_20),
    Task(number=21, filename="21_tournament_rampages.sql",
         title="Разгромные выступления на турнирах",
         columns=["match_id", "tournament", "player", "hero", "kda"],
         ordered=True, expected=expected_21),
    Task(number=22, filename="22_above_platform_average.sql",
         title="Стримеры крупнее среднего по своей площадке",
         columns=["streamer", "platform", "followers", "platform_avg", "team"],
         ordered=True, expected=expected_22),
    Task(number=23, filename="23_team_hoppers.sql",
         title="Игроки, сменившие больше одной команды",
         columns=["player", "country", "teams_count", "current_team", "streamer"],
         ordered=True, expected=expected_23),
    Task(number=24, filename="24_prize_pool_outgrowth.sql",
         title="Турниры, обогнавшие всю предыдущую историю",
         columns=["tournament", "started_at", "prize_pool", "prev_total",
                  "prev_count", "matches_played"],
         ordered=True, expected=expected_24),
]

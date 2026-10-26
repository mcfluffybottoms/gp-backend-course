"""Группа 3, задачи 13-18: группировка и агрегаты.

Ответ каждой задачи считается здесь заново, на чистом Python, по исходным
таблицам из harness.table(). Ни одного SQL-запроса в этом файле нет и быть
не должно: иначе проверка сведётся к сравнению запроса с самим собой.
Группировки — это словари, соединения — поиск по словарю, сортировки —
list.sort() с ключом, повторяющим ORDER BY из условия.

Дроби считаются в decimal.Decimal, а не во float: round(numeric, 2)
в PostgreSQL округляет половину ВВЕРХ (от нуля), поэтому здесь взят
ROUND_HALF_UP. Во float половина попала бы не туда и ответ разошёлся бы
с запросом в последнем знаке.

База поднята с локалью C, то есть текст в ней сравнивается побайтово —
ровно так же, как сравнивает строки Python, так что возни с collation
не требуется.
"""
import decimal

from task import Task
import harness

CENT = decimal.Decimal("0.01")
ZERO = decimal.Decimal("0")


def round2(value):
    """Округление до двух знаков по правилу PostgreSQL: половина — вверх."""
    return value.quantize(CENT, rounding=decimal.ROUND_HALF_UP)


def ratio2(numerator, denominator):
    """Дробное деление двух целых с округлением до двух знаков."""
    return round2(decimal.Decimal(numerator) / decimal.Decimal(denominator))


# ---------------------------------------------------------------------
# 13. Сколько матчей сыграно в каждом году
# ---------------------------------------------------------------------

def expected_13():
    per_year = {}
    for m in harness.table("matches"):
        # started_at приходит с зоной UTC, поэтому .year — это год по UTC.
        cell = per_year.setdefault(m["started_at"].year, [0, 0])
        cell[0] += 1
        if m["tournament_id"] is not None:
            cell[1] += 1
    rows = [(year, total, with_tournament)
            for year, (total, with_tournament) in per_year.items()]
    rows.sort(key=lambda r: r[0])
    return rows


# ---------------------------------------------------------------------
# 14. Средние убийства, смерти и помощь у ходовых героев
# ---------------------------------------------------------------------

MIN_GAMES = 420


def expected_14():
    hero_name = {h["hero_id"]: h["name"] for h in harness.table("heroes")}

    # hero_id -> [игр, сумма убийств, сумма смертей, сумма помощи]
    totals = {}
    for mp in harness.table("match_players"):
        cell = totals.setdefault(mp["hero_id"], [0, 0, 0, 0])
        cell[0] += 1
        cell[1] += mp["kills"]
        cell[2] += mp["deaths"]
        cell[3] += mp["assists"]

    rows = []
    for hero_id, (games, kills, deaths, assists) in totals.items():
        if games < MIN_GAMES:
            continue
        rows.append((hero_name[hero_id], games,
                     ratio2(kills, games),
                     ratio2(deaths, games),
                     ratio2(assists, games)))
    # По округлённым средним убийствам вниз, при равенстве — по имени.
    rows.sort(key=lambda r: (-r[2], r[0]))
    return rows


# ---------------------------------------------------------------------
# 15. Сколько донатов собрал каждый стример
# ---------------------------------------------------------------------

def expected_15():
    platform_name = {p["platform_id"]: p["name"]
                     for p in harness.table("platforms")}
    team_name = {t["team_id"]: t["name"] for t in harness.table("teams")}

    # Действующая команда игрока: строка состава с пустым left_at.
    current_team = {}
    for tm in harness.table("team_members"):
        if tm["left_at"] is None:
            current_team[tm["player_id"]] = team_name[tm["team_id"]]

    stream_owner = {s["stream_id"]: s["streamer_id"]
                    for s in harness.table("streams")}

    # streamer_id -> [число донатов, сумма]
    donations = {}
    for d in harness.table("stream_donations"):
        cell = donations.setdefault(stream_owner[d["stream_id"]], [0, ZERO])
        cell[0] += 1
        cell[1] += d["amount"]

    rows = []
    for s in harness.table("streamers"):
        count, total = donations.get(s["streamer_id"], (0, ZERO))
        team = None
        if s["player_id"] is not None:
            team = current_team.get(s["player_id"])
        rows.append((s["nickname"], platform_name[s["platform_id"]], team,
                     count, round2(total)))
    rows.sort(key=lambda r: (-r[4], r[0]))
    return rows


# ---------------------------------------------------------------------
# 16. Десятка самых банимых героев
# ---------------------------------------------------------------------

TOP_BANNED = 10


def expected_16():
    hero_name = {h["hero_id"]: h["name"] for h in harness.table("heroes")}

    bans = {}
    for b in harness.table("match_bans"):
        bans[b["hero_id"]] = bans.get(b["hero_id"], 0) + 1

    picks = {}
    for mp in harness.table("match_players"):
        picks[mp["hero_id"]] = picks.get(mp["hero_id"], 0) + 1

    rows = []
    for hero_id, ban_count in bans.items():
        pick_count = picks.get(hero_id, 0)
        if pick_count == 0:
            continue
        rows.append((hero_name[hero_id], ban_count, pick_count,
                     ratio2(ban_count, pick_count)))
    # Сначала полная сортировка по обоим ключам, только потом отсечение.
    rows.sort(key=lambda r: (-r[1], r[0]))
    return rows[:TOP_BANNED]


# ---------------------------------------------------------------------
# 17. Доля побед светлой стороны по патчам
# ---------------------------------------------------------------------

def expected_17():
    version = {p["patch_id"]: p["version"] for p in harness.table("patches")}

    # patch_id -> [матчей, побед света]
    totals = {}
    for m in harness.table("matches"):
        cell = totals.setdefault(m["patch_id"], [0, 0])
        cell[0] += 1
        if m["winner"] == "radiant":
            cell[1] += 1

    rows = []
    for patch_id, (matches, wins) in totals.items():
        rows.append((version[patch_id], matches, wins,
                     ratio2(100 * wins, matches)))
    rows.sort(key=lambda r: (-r[3], r[0]))
    return rows


# ---------------------------------------------------------------------
# 18. Призовые турниров, до которых добрались игроки команды
# ---------------------------------------------------------------------

def expected_18():
    teams = harness.table("teams")
    prize = {t["tournament_id"]: t["prize_pool"]
             for t in harness.table("tournaments")}

    # Турнирные матчи: match_id -> (tournament_id, день матча по UTC).
    match = {}
    for m in harness.table("matches"):
        if m["tournament_id"] is not None:
            match[m["match_id"]] = (m["tournament_id"], m["started_at"].date())

    # Периоды игрока в командах: player_id -> [(team_id, joined_at, left_at)].
    spells = {}
    for tm in harness.table("team_members"):
        spells.setdefault(tm["player_id"], []).append(
            (tm["team_id"], tm["joined_at"], tm["left_at"]))

    # Различные пары (команда, турнир): турнир засчитывается один раз.
    pairs = set()
    for mp in harness.table("match_players"):
        played = match.get(mp["match_id"])
        if played is None:
            continue
        tournament_id, day = played
        for team_id, joined_at, left_at in spells.get(mp["player_id"], ()):
            if day >= joined_at and (left_at is None or day < left_at):
                pairs.add((team_id, tournament_id))

    # team_id -> [число турниров, сумма призовых]
    totals = {}
    for team_id, tournament_id in pairs:
        cell = totals.setdefault(team_id, [0, 0])
        cell[0] += 1
        cell[1] += prize[tournament_id]

    rows = []
    for t in teams:
        if t["team_id"] not in totals:
            continue
        tournaments, prize_total = totals[t["team_id"]]
        rows.append((t["name"], t["tag"], tournaments, prize_total))
    rows.sort(key=lambda r: (-r[3], r[0]))
    return rows


TASKS = [
    Task(number=13, filename="13_matches_per_year.sql",
         title="Сколько матчей сыграно в каждом году",
         columns=["year", "matches", "tournament_matches"],
         ordered=True, expected=expected_13),
    Task(number=14, filename="14_hero_kda.sql",
         title="Средние убийства, смерти и помощь у ходовых героев",
         columns=["hero", "games", "avg_kills", "avg_deaths", "avg_assists"],
         ordered=True, expected=expected_14),
    Task(number=15, filename="15_streamer_donations.sql",
         title="Сколько донатов собрал каждый стример",
         columns=["streamer", "platform", "team", "donations", "total_amount"],
         ordered=True, expected=expected_15),
    Task(number=16, filename="16_most_banned_heroes.sql",
         title="Десятка самых банимых героев",
         columns=["hero", "bans", "picks", "bans_per_pick"],
         ordered=True, expected=expected_16),
    Task(number=17, filename="17_radiant_winrate_by_patch.sql",
         title="Доля побед светлой стороны по патчам",
         columns=["version", "matches", "radiant_wins", "radiant_winrate"],
         ordered=True, expected=expected_17),
    Task(number=18, filename="18_team_prize_pools.sql",
         title="Призовые турниров, до которых добрались игроки команды",
         columns=["team", "tag", "tournaments", "prize_total"],
         ordered=True, expected=expected_18),
]

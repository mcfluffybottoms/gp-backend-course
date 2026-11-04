"""Обвязка SQL-домашней работы.

Запускает запрос студента из .sql в PostgreSQL, отдельно считает тот же ответ
на Python по исходным таблицам и сравнивает результаты.

Доступ к базе идёт через psql внутри контейнера, поэтому драйвер ставить не нужно:
хватает Docker и Python из системы.
"""
import csv
import datetime
import decimal
import io
import os
import pathlib
import subprocess

HW_DIR = pathlib.Path(os.environ.get("HW_TASK_DIR")
                      or pathlib.Path(__file__).resolve().parent.parent)
QUERIES_DIR = pathlib.Path(os.environ.get("HW_QUERIES_DIR") or (HW_DIR / "queries"))
SERVICE = "postgres"
DB_USER = "student"
DB_NAME = "shop"

# Типы колонок исходных таблиц: по ним значения из psql приводятся к Python.
SCHEMA = {
    "platforms": {"platform_id": int, "name": str},
    "patches": {"patch_id": int, "version": str, "released_at": datetime.date},
    "heroes": {"hero_id": int, "name": str, "primary_attr": str,
               "attack_type": str, "legs": int},
    "hero_roles": {"hero_id": int, "role": str},
    "players": {"player_id": int, "nickname": str, "country": str, "mmr": int,
                "behaviour_score": int, "registered_at": datetime.date},
    "teams": {"team_id": int, "name": str, "tag": str, "founded_at": datetime.date},
    "team_members": {"team_id": int, "player_id": int,
                     "joined_at": datetime.date, "left_at": datetime.date},
    "tournaments": {"tournament_id": int, "name": str, "prize_pool": int,
                    "started_at": datetime.date, "patch_id": int},
    "matches": {"match_id": int, "tournament_id": int,
                "started_at": datetime.datetime, "duration_sec": int,
                "winner": str, "patch_id": int},
    "match_bans": {"match_id": int, "hero_id": int, "side": str, "order_no": int},
    "match_players": {"match_id": int, "slot": int, "player_id": int,
                      "hero_id": int, "side": str, "kills": int, "deaths": int,
                      "assists": int, "last_hits": int, "gpm": int, "xpm": int,
                      "net_worth": int, "courier_kills": int},
    "items": {"item_id": int, "name": str, "cost": int, "is_recipe": bool},
    "item_recipe": {"item_id": int, "component_id": int, "quantity": int},
    "match_items": {"match_id": int, "slot": int, "item_id": int,
                    "bought_at_sec": int},
    "streamers": {"streamer_id": int, "nickname": str, "platform_id": int,
                  "player_id": int, "followers": int,
                  "started_at": datetime.date},
    "streams": {"stream_id": int, "streamer_id": int,
                "started_at": datetime.datetime, "duration_min": int,
                "peak_viewers": int, "avg_viewers": int, "title": str},
    "stream_donations": {"donation_id": int, "stream_id": int,
                         "amount": decimal.Decimal, "sent_at_sec": int,
                         "nickname": str},
}


# --------------------------------------------------------------------------
# доступ к базе
# --------------------------------------------------------------------------

def compose(*args, timeout=600, check=True, stdin=None):
    cmd = ["docker", "compose", *args]
    r = subprocess.run(cmd, cwd=HW_DIR, input=stdin, capture_output=True,
                       text=True, timeout=timeout)
    if check and r.returncode != 0:
        raise AssertionError("«%s» завершилась с кодом %d\n%s%s"
                             % (" ".join(cmd), r.returncode, r.stdout, r.stderr))
    return r


def run_sql(sql, timeout=120):
    """Выполняет запрос и возвращает (список колонок, список строк со строковыми значениями)."""
    r = compose("exec", "-T", SERVICE,
                "psql", "-U", DB_USER, "-d", DB_NAME,
                "--csv", "-v", "ON_ERROR_STOP=1", "-f", "-",
                stdin=sql, timeout=timeout, check=False)
    if r.returncode != 0:
        raise SQLError(r.stderr.strip() or r.stdout.strip())
    rows = list(csv.reader(io.StringIO(r.stdout)))
    if not rows:
        return [], []
    return rows[0], rows[1:]


class SQLError(Exception):
    """PostgreSQL отверг запрос."""


# --------------------------------------------------------------------------
# исходные таблицы для расчёта на Python
# --------------------------------------------------------------------------

_CACHE = {}


def _cast(value, typ):
    if value == "":
        return None
    if typ is int:
        return int(value)
    if typ is decimal.Decimal:
        return decimal.Decimal(value)
    if typ is bool:
        return value in ("t", "true", "True", "1")
    if typ is datetime.date:
        return datetime.date.fromisoformat(value)
    if typ is datetime.datetime:
        return datetime.datetime.fromisoformat(value)
    return value


def table(name):
    """Возвращает таблицу целиком как список словарей с приведёнными типами."""
    if name in _CACHE:
        return _CACHE[name]
    if name not in SCHEMA:
        raise AssertionError("таблица %s не описана в SCHEMA" % name)
    types = SCHEMA[name]
    cols, rows = run_sql("SELECT %s FROM %s;" % (", ".join(types), name))
    out = [{c: _cast(v, types[c]) for c, v in zip(cols, row)} for row in rows]
    _CACHE[name] = out
    return out


def reset_cache():
    _CACHE.clear()


# --------------------------------------------------------------------------
# сравнение результата запроса с расчётом на Python
# --------------------------------------------------------------------------

def _canon(expected_value, raw):
    """Приводит строку из psql к виду, сравнимому с ожидаемым значением."""
    if expected_value is None:
        return None if raw == "" else raw
    if raw == "":
        return None
    if isinstance(expected_value, bool):
        return raw in ("t", "true", "True", "1")
    if isinstance(expected_value, int):
        try:
            return int(raw)
        except ValueError:
            return raw
    if isinstance(expected_value, (decimal.Decimal, float)):
        try:
            return decimal.Decimal(raw).quantize(decimal.Decimal("0.01"))
        except (decimal.InvalidOperation, ValueError):
            return raw
    if isinstance(expected_value, datetime.datetime):
        try:
            return datetime.datetime.fromisoformat(raw)
        except ValueError:
            return raw
    if isinstance(expected_value, datetime.date):
        try:
            return datetime.date.fromisoformat(raw)
        except ValueError:
            return raw
    return raw


def _norm_expected(value):
    if isinstance(value, (decimal.Decimal, float)) and not isinstance(value, bool):
        return decimal.Decimal(str(value)).quantize(decimal.Decimal("0.01"))
    return value


def _fmt_row(row):
    return "(" + ", ".join("NULL" if v is None else str(v) for v in row) + ")"


def _diff_report(columns, want, got, ordered, limit=6):
    lines = []
    if ordered:
        for i, (w, g) in enumerate(zip(want, got)):
            if w != g:
                lines.append("  строка %d:" % (i + 1))
                lines.append("    ожидалось %s" % _fmt_row(w))
                lines.append("    получено  %s" % _fmt_row(g))
                if len(lines) > limit * 3:
                    break
        if len(want) != len(got):
            lines.append("  строк ожидалось %d, получено %d" % (len(want), len(got)))
    else:
        missing = [r for r in want if r not in got][:limit]
        extra = [r for r in got if r not in want][:limit]
        if missing:
            lines.append("  нет в ответе запроса:")
            lines += ["    " + _fmt_row(r) for r in missing]
        if extra:
            lines.append("  лишние в ответе запроса:")
            lines += ["    " + _fmt_row(r) for r in extra]
        if len(want) != len(got):
            lines.append("  строк ожидалось %d, получено %d" % (len(want), len(got)))
    return "\n".join(lines) if lines else "  различий по строкам не найдено"


def check(task, expected_rows):
    """Выполняет .sql задачи и сверяет результат с расчётом на Python."""
    path = QUERIES_DIR / task.filename
    if not path.exists():
        raise AssertionError("нет файла %s" % path)
    sql = path.read_text(encoding="utf-8")
    if not _has_statement(sql):
        raise AssertionError(
            "в файле %s нет запроса — он состоит только из комментариев" % task.filename)

    try:
        cols, raw_rows = run_sql(sql)
    except SQLError as exc:
        raise AssertionError("PostgreSQL отверг запрос из %s:\n%s"
                             % (task.filename, exc)) from None

    if [c.lower() for c in cols] != [c.lower() for c in task.columns]:
        raise AssertionError(
            "запрос из %s должен вернуть колонки %s, а вернул %s.\n"
            "Имена и порядок колонок заданы в условии: по ним сверяется результат."
            % (task.filename, ", ".join(task.columns), ", ".join(cols) or "ничего"))

    want = [tuple(_norm_expected(v) for v in row) for row in expected_rows]
    got = [tuple(_canon(w, r) for w, r in zip(want[0] if want else [None] * len(row), row))
           if want else tuple(row) for row in raw_rows]

    if not task.ordered:
        want_cmp, got_cmp = sorted(want, key=_sort_key), sorted(got, key=_sort_key)
    else:
        want_cmp, got_cmp = want, got

    if want_cmp == got_cmp:
        return

    raise AssertionError(
        "результат запроса из %s не совпал с расчётом на Python.\n"
        "%s\n%s"
        % (task.filename,
           "Порядок строк задан условием." if task.ordered
           else "Порядок строк не важен, сравнение идёт как множеств.",
           _diff_report(task.columns, want_cmp, got_cmp, task.ordered)))


def _sort_key(row):
    return tuple((v is None, str(v)) for v in row)


def _has_statement(sql):
    body = []
    for line in sql.splitlines():
        line = line.split("--", 1)[0].strip()
        if line:
            body.append(line)
    return bool(body)

"""Расчёт ответов на Python.

Каждая группа задач лежит в своём модуле g1.py, g2.py, ... Пакет собирает
их списки TASKS в один, отсортированный по номеру задачи. Модули групп
пишут «from task import Task» и «import harness», поэтому каталоги
oracle/ и tests/ добавляются в sys.path.

Модуля какой-то группы может ещё не быть на диске, а лежащий модуль может
оказаться недописанным. Ни то, ни другое не должно валить прогон целиком:
недостающие группы пропускаются молча, сломанные — с предупреждением
в stderr, а задачи остальных групп всё равно собираются и проверяются.
"""
import importlib
import pathlib
import sys
import traceback

HERE = pathlib.Path(__file__).resolve().parent
for _p in (HERE, HERE.parent / "tests"):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))

from task import Task  # noqa: E402,F401  (реэкспорт для удобства)

GROUPS = ("g1", "g2", "g3", "g4", "g5")

TASKS = []
ABSENT = []   # группы, модуля которых нет на диске
BROKEN = []   # группы, модуль которых не импортировался

for _name in GROUPS:
    if not (HERE / ("%s.py" % _name)).exists():
        ABSENT.append(_name)
        continue
    try:
        _module = importlib.import_module(_name)
    except Exception:  # noqa: BLE001 — соседняя группа не должна валить прогон
        BROKEN.append(_name)
        print("предупреждение: модуль задач %s не импортировался:\n%s"
              % (_name, traceback.format_exc()), file=sys.stderr)
        continue
    TASKS.extend(getattr(_module, "TASKS", []))

TASKS.sort(key=lambda t: t.number)

if ABSENT:
    print("предупреждение: нет модулей задач %s" % ", ".join(ABSENT),
          file=sys.stderr)

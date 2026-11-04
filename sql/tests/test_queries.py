"""Один тест на задачу: выполняет .sql и сверяет результат с расчётом на Python.

Запросы берутся из каталога queries, а при проверке эталона — из каталога,
указанного в HW_QUERIES_DIR. Расчёт на Python лежит в oracle/ и читает
исходные таблицы напрямую, поэтому совпадение результатов что-то значит.
"""
import pathlib
import sys
import unittest

HERE = pathlib.Path(__file__).resolve().parent
for p in (str(HERE), str(HERE.parent)):
    if p not in sys.path:
        sys.path.insert(0, p)

import harness  # noqa: E402
import oracle  # noqa: E402


def setUpModule():
    harness.compose("up", "-d", "--wait")
    harness.reset_cache()


class Queries(unittest.TestCase):
    maxDiff = None


def _case(task):
    def test(self):
        self.assertTrue(task.columns, "у задачи не заданы колонки")
        harness.check(task, task.expected())
    test.__doc__ = "%02d. %s" % (task.number, task.title)
    return test


def _install():
    seen = set()
    for task in sorted(oracle.TASKS, key=lambda t: t.number):
        if task.number in seen:
            raise RuntimeError("номер задачи %d встречается дважды" % task.number)
        seen.add(task.number)
        stem = pathlib.Path(task.filename).stem
        setattr(Queries, "test_%s" % stem, _case(task))
    missing = [n for n in range(1, 31) if n not in seen]
    if missing:
        print("предупреждение: нет задач с номерами %s"
              % ", ".join(str(n) for n in missing), file=sys.stderr)


_install()

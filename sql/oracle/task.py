"""Описание одной задачи домашней работы.

Задача связывает файл с запросом студента и расчёт того же ответа на Python:
обвязка выполняет .sql, вызывает expected() и сравнивает результаты.

    number   — номер задачи, он же порядок в списке;
    filename — имя файла запроса внутри каталога queries;
    title    — название задачи, оно попадает в вывод теста;
    columns  — имена колонок ровно в том порядке, в каком их требует условие;
    ordered  — True, если условие задаёт порядок строк; иначе сравнение
               идёт как сравнение множеств;
    expected — функция без аргументов, возвращающая список кортежей.
"""


class Task:
    __slots__ = ("number", "filename", "title", "columns", "ordered", "expected")

    def __init__(self, number, filename, title, columns, ordered, expected):
        if not columns:
            raise ValueError("у задачи %s не заданы колонки" % number)
        if not callable(expected):
            raise TypeError("expected должен быть функцией без аргументов")
        self.number = int(number)
        self.filename = str(filename)
        self.title = str(title)
        self.columns = list(columns)
        self.ordered = bool(ordered)
        self.expected = expected

    def __repr__(self):
        return "Task(%d, %r)" % (self.number, self.filename)

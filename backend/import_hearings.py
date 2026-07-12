"""
Імпортер відкритих даних 'Список справ призначених до розгляду' у
локальний SQLite-індекс (FTS5) для швидкого пошуку засідань за ПІБ.

Запуск вручну (у backend/, з активованим venv):
    python3 import_hearings.py

Автоматично — раз на добу через systemd-таймер
(server/hearings-import.timer). Пише в backend/data/hearings.db
(або HEARINGS_DB_PATH), атомарно підмінюючи попередню базу.
"""

import time

from app import hearings_db
from app.hearings import iter_all_hearings


def main():
    t0 = time.time()
    print("[import] Починаю побудову індексу засідань...")
    count = hearings_db.build(iter_all_hearings())
    dt = time.time() - t0
    print(f"[import] Готово: {count} унікальних засідань за {dt:.0f}с")
    print(f"[import] База: {hearings_db.DB_PATH}")


if __name__ == "__main__":
    main()

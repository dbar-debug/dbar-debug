"""
Тест: отримання власних судових справ з cabinet.court.gov.ua через
внутрішній JSON API (без HTML-scraping).
Використання:
    python3 test_cabinet_cases.py /шлях/до/ключа.jks ВашПароль
"""

import asyncio
import sys

from app.cabinet_auth import get_session
from app.cabinet_scraper import get_my_cases


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 test_cabinet_cases.py /шлях/до/ключа.jks ВашПароль")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = " ".join(sys.argv[2:])

    print("Авторизуюсь (використає кешовану сесію, якщо вона ще свіжа)...")
    session = await get_session(kep_file, password)

    print("Отримую справи через /api/cases/my ...")
    result = await get_my_cases(session)

    print(f"\nЗнайдено {result.total_found} справ:\n")
    for c in result.cases:
        print(f"  № {c.case_number} | {c.court_name} | {c.date} | Моя роль: {c.document_type}")
        print(f"    {c.url}")


asyncio.run(main())

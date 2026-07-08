"""
Тест авторизації через КЕП.
Використання:
    python3 test_cabinet_auth.py /шлях/до/ключа.jks ВашПароль
"""

import asyncio
import sys
from pathlib import Path

from app.cabinet_auth import authenticate
from app.cabinet_scraper import get_my_cases


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 test_cabinet_auth.py /шлях/до/ключа.jks ВашПароль")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = sys.argv[2]

    print(f"Авторизуюсь з файлом: {Path(kep_file).name}")
    print("Це може зайняти 20-30 секунд...\n")

    try:
        cookies = await authenticate(kep_file, password)
        print(f"\nАвторизація успішна! Отримано {len(cookies)} cookies")

        print("\nОтримую список справ...")
        result = await get_my_cases(cookies)

        if result.cases:
            print(f"\nЗнайдено {result.total_found} справ:")
            for c in result.cases:
                print(f"  № {c.case_number} | {c.date} | {c.court_name}")
        else:
            print("\nСправ не знайдено (або потрібно оновити селектори — перевірте debug_output/cabinet_cases.png)")

    except Exception as e:
        print(f"\nПомилка: {e}")
        sys.exit(1)


asyncio.run(main())

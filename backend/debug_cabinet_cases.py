"""
Debug: авторизація через КЕП + перехід у "Мої справи" щоб знайти реальні селектори.
Використання:
    python3 debug_cabinet_cases.py /шлях/до/ключа.jks ВашПароль
"""

import asyncio
import sys
from pathlib import Path

from app.cabinet_auth import get_session

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)


async def snap(page, name):
    path = str(OUT / f"cases_{name}.png")
    await page.screenshot(path=path, full_page=True)
    html = await page.content()
    (OUT / f"cases_{name}.html").write_text(html, encoding="utf-8")
    print(f"  [snap] {name} | url={page.url} | html={len(html)} байт")


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 debug_cabinet_cases.py /шлях/до/ключа.jks ВашПароль")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = " ".join(sys.argv[2:])

    from playwright.async_api import async_playwright

    print("[1] Авторизуюсь через КЕП (кешована сесія, якщо свіжа)...")
    cookies = await get_session(kep_file, password)
    print(f"[OK] Отримано {len(cookies)} cookies\n")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True, args=["--no-sandbox"])
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="uk-UA",
            viewport={"width": 1280, "height": 900},
        )
        await context.add_cookies(cookies)
        page = await context.new_page()

        print("[2] Відкриваю cabinet.court.gov.ua/ ...")
        await page.goto("https://cabinet.court.gov.ua/", wait_until="networkidle", timeout=30_000)
        await asyncio.sleep(2)
        await snap(page, "1_home")

        print("\n[3] Шукаю посилання 'Мої справи' ...")
        link = await page.query_selector("text=Мої справи")
        if link:
            href = await link.get_attribute("href")
            print(f"  [OK] Знайдено, href={href}")
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(3)
        else:
            print("  ПОМИЛКА: посилання 'Мої справи' не знайдено!")

        await snap(page, "2_moi_spravy")

        print(f"\n[4] Поточний URL: {page.url}")

        # Вивести структуру: заголовки таблиці, класи рядків
        print("\n[5] Аналізую структуру сторінки...")
        info = await page.evaluate("""() => {
            const tables = document.querySelectorAll('table');
            const rows = document.querySelectorAll('tr');
            const cards = document.querySelectorAll('[class*="card"], [class*="Card"], [class*="item"], [class*="Item"]');
            return {
                tables: tables.length,
                rows: rows.length,
                cards: cards.length,
                firstRowsHtml: Array.from(rows).slice(0, 3).map(r => r.outerHTML.substring(0, 500)),
                firstCardsHtml: Array.from(cards).slice(0, 3).map(c => c.outerHTML.substring(0, 500)),
            };
        }""")
        print(f"  Таблиць: {info['tables']}")
        print(f"  Рядків tr: {info['rows']}")
        print(f"  Card-подібних елементів: {info['cards']}")
        print("\n  Перші рядки tr:")
        for h in info["firstRowsHtml"]:
            print(f"    {h}\n")
        print("\n  Перші card-елементи:")
        for h in info["firstCardsHtml"]:
            print(f"    {h}\n")

        await browser.close()

    print("\nГотово! Перевірте debug_output/cases_*.png та cases_*.html")


asyncio.run(main())

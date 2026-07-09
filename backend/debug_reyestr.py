"""
Debug: перевіряє актуальну верстку reyestr.court.gov.ua — форму пошуку
і структуру результатів. Використовується коли пошук у реєстрі перестав
працювати (сайт змінив HTML).

Використання:
    python3 debug_reyestr.py "Барцуков Денис Станіславович"
"""

import asyncio
import sys
from pathlib import Path

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

REGISTRY_URL = "https://reyestr.court.gov.ua"


async def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "Барцуков Денис Станіславович"
    print(f"Пошук: {name}\n")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True, args=["--no-sandbox"])
        page = await browser.new_page(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="uk-UA",
        )

        print(f"[1] Відкриваю {REGISTRY_URL} ...")
        await page.goto(REGISTRY_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(2)
        await page.screenshot(path=str(OUT / "reyestr_1_home.png"), full_page=True)

        # Шукаємо поле пошуку
        print("\n[2] Аналізую форму пошуку...")
        inputs = await page.evaluate("""() => {
            return Array.from(document.querySelectorAll('input, textarea')).map(e => ({
                tag: e.tagName, id: e.id, name: e.name, type: e.type,
                placeholder: e.placeholder, cls: String(e.className).slice(0, 40)
            }));
        }""")
        for i in inputs:
            print(f"  {i}")

        print("\n[3] Кнопки/сабміти:")
        buttons = await page.evaluate("""() => {
            return Array.from(document.querySelectorAll('button, input[type=submit], a.btn, #btn'))
                .map(e => ({tag: e.tagName, id: e.id, type: e.type,
                            text: (e.innerText||e.value||'').slice(0,30),
                            cls: String(e.className).slice(0,40)}));
        }""")
        for b in buttons:
            print(f"  {b}")

        # Пробуємо ввести і сабмітнути через #SearchExpression / #btn
        search_input = await page.query_selector("#SearchExpression")
        if search_input:
            print("\n[4] Знайдено #SearchExpression — вводжу текст і сабмічу #btn...")
            await search_input.fill(name)
            btn = await page.query_selector("#btn")
            if btn:
                await btn.click()
            else:
                print("  #btn не знайдено — пробую Enter")
                await search_input.press("Enter")

            try:
                await page.wait_for_load_state("networkidle", timeout=20_000)
            except PWTimeout:
                pass
            await asyncio.sleep(2)
            print(f"  URL після сабміту: {page.url}")
        else:
            print("\n[4] #SearchExpression НЕ знайдено — форма змінилась!")

        await page.screenshot(path=str(OUT / "reyestr_2_results.png"), full_page=True)
        (OUT / "reyestr_results.html").write_text(await page.content(), encoding="utf-8")

        # Аналізуємо результати
        print("\n[5] Структура результатів:")
        info = await page.evaluate("""() => {
            const tables = document.querySelectorAll('table');
            const trOdd = document.querySelectorAll('tr.odd, tr.even');
            const allTr = document.querySelectorAll('tr');
            const reviewLinks = document.querySelectorAll("a[href*='/Review/']");
            return {
                tables: tables.length,
                trOddEven: trOdd.length,
                allTr: allTr.length,
                reviewLinks: reviewLinks.length,
                firstRows: Array.from(allTr).slice(0, 4).map(r => r.outerHTML.slice(0, 400)),
                bodyTextStart: document.body.innerText.slice(0, 400),
            };
        }""")
        print(f"  Таблиць: {info['tables']}")
        print(f"  tr.odd/tr.even: {info['trOddEven']}")
        print(f"  Всього tr: {info['allTr']}")
        print(f"  Посилань /Review/: {info['reviewLinks']}")
        print(f"\n  Початок тексту сторінки:\n  {info['bodyTextStart']}")
        print("\n  Перші рядки таблиці:")
        for r in info["firstRows"]:
            print(f"    {r}\n")

        await browser.close()

    print("\nГотово! Скриншоти: debug_output/reyestr_1_home.png, reyestr_2_results.png")
    print("HTML результатів: debug_output/reyestr_results.html")


asyncio.run(main())

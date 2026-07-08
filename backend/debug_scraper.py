"""
Debug script: opens reyestr.court.gov.ua, performs a search,
saves screenshot + HTML so we can find the correct CSS selectors.

Run: python3 debug_scraper.py "Барцуков Денис Станіславович"
"""

import asyncio
import sys
from pathlib import Path
from playwright.async_api import async_playwright

NAME = sys.argv[1] if len(sys.argv) > 1 else "Іваненко Іван Іванович"
OUT_DIR = Path("debug_output")
OUT_DIR.mkdir(exist_ok=True)


async def main():
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="uk-UA",
        )
        page = await context.new_page()

        # ── 1. Головна сторінка ──────────────────────────────────────────
        print("[1] Відкриваю reyestr.court.gov.ua ...")
        await page.goto("https://reyestr.court.gov.ua", wait_until="networkidle", timeout=30_000)

        await page.screenshot(path=str(OUT_DIR / "1_homepage.png"), full_page=True)
        (OUT_DIR / "1_homepage.html").write_text(await page.content(), encoding="utf-8")
        print("    Збережено: debug_output/1_homepage.png + .html")

        # ── 2. Всі input-поля на сторінці ───────────────────────────────
        inputs = await page.query_selector_all("input")
        print(f"\n[2] Знайдено input-полів: {len(inputs)}")
        for i, inp in enumerate(inputs):
            attrs = {}
            for attr in ["type", "name", "id", "placeholder", "class"]:
                val = await inp.get_attribute(attr)
                if val:
                    attrs[attr] = val
            print(f"    [{i}] {attrs}")

        # ── 3. Ввести ім'я і натиснути кнопку пошуку ────────────────────
        print(f"\n[3] Вводжу в #SearchExpression: {NAME}")
        await page.fill("#SearchExpression", NAME)

        print("    Клікаю кнопку #btn ...")
        await page.click("#btn")

        # Чекаємо поки AJAX завантажить результати
        print("    Очікую результати (AJAX) ...")
        await page.wait_for_load_state("networkidle", timeout=20_000)

        # Додатково чекаємо появи будь-якого блоку результатів
        try:
            await page.wait_for_selector(
                ".results, #results, .result, tr.even, tr.odd, div[id*='result'], table.resultsT",
                timeout=10_000,
            )
            print("    Знайдено блок результатів!")
        except Exception:
            print("    УВАГА: блок результатів не знайдено за відомими селекторами")

            # ── 4. Сторінка результатів ──────────────────────────────────
            await page.screenshot(path=str(OUT_DIR / "2_results.png"), full_page=True)
            (OUT_DIR / "2_results.html").write_text(await page.content(), encoding="utf-8")
            print("    Збережено: debug_output/2_results.png + .html")
            print(f"    URL після пошуку: {page.url}")

            # ── 5. Що є на сторінці результатів ─────────────────────────
            print("\n[5] Перші 30 class-атрибутів елементів на сторінці результатів:")
            els = await page.query_selector_all("[class]")
            classes_seen = set()
            for el in els[:100]:
                cls = await el.get_attribute("class")
                if cls and cls not in classes_seen:
                    classes_seen.add(cls)
                    tag = await el.evaluate("el => el.tagName.toLowerCase()")
                    print(f"    <{tag} class='{cls}'>")
                if len(classes_seen) >= 30:
                    break

        await browser.close()
        print("\nГотово! Відкрийте debug_output/2_results.png щоб побачити сторінку результатів.")


asyncio.run(main())

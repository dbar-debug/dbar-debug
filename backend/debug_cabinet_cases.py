"""
Debug: авторизація через КЕП + перехід у "Мої справи" щоб знайти реальні селектори.
Використання:
    python3 debug_cabinet_cases.py /шлях/до/ключа.jks ВашПароль
"""

import asyncio
import json
import sys
from pathlib import Path

from app.cabinet_auth import get_session, clear_session, apply_session

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

# Тут накопичуємо всі XHR/fetch-відповіді з JSON, зроблені сторінкою —
# так можна знайти внутрішній API cabinet.court.gov.ua і працювати з ним
# напряму (JSON) замість крихкого парсингу HTML-таблиць.
API_CALLS = []


def make_response_logger():
    async def on_response(response):
        try:
            req = response.request
            if req.resource_type not in ("xhr", "fetch"):
                return
            url = response.url
            status = response.status
            ctype = response.headers.get("content-type", "")
            if "json" not in ctype:
                return
            try:
                body = await response.text()
            except Exception:
                body = ""
            entry = {
                "method": req.method,
                "url": url,
                "status": status,
                "body_preview": body[:2000],
            }
            API_CALLS.append(entry)
            print(f"  [api] {req.method} {status} {url}")
        except Exception as e:
            print(f"  [api] помилка логування відповіді: {e}")
    return on_response


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

    print("[1] Авторизуюсь через КЕП (примусово свіжа сесія)...")
    clear_session()  # під час дебагу завжди логінимось заново, кеш може бути невалідний
    session = await get_session(kep_file, password)
    print(
        f"[OK] Отримано {len(session['cookies'])} cookies, "
        f"{len(session['local_storage'])} ключів localStorage\n"
    )

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
        await apply_session(context, session)
        page = await context.new_page()
        page.on("response", make_response_logger())

        print("[2] Відкриваю cabinet.court.gov.ua/ ...")
        await page.goto("https://cabinet.court.gov.ua/", wait_until="networkidle", timeout=30_000)
        await asyncio.sleep(2)

        # Діагностика: чи справді localStorage застосувався в цьому контексті
        actual_ls_keys = await page.evaluate("() => Object.keys(window.localStorage)")
        print(f"  [diag] Ключі localStorage на сторінці зараз: {actual_ls_keys}")

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

    # Зберегти всі перехоплені JSON API-виклики
    (OUT / "cases_api_calls.json").write_text(
        json.dumps(API_CALLS, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n[6] Перехоплено {len(API_CALLS)} JSON API-викликів (див. debug_output/cases_api_calls.json)")
    for c in API_CALLS:
        print(f"  {c['method']} {c['status']} {c['url']}")
        print(f"    preview: {c['body_preview'][:300]}")

    print("\nГотово! Перевірте debug_output/cases_*.png, cases_*.html та cases_api_calls.json")


asyncio.run(main())

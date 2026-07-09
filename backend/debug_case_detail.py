"""
Debug: відкриває сторінку КОНКРЕТНОЇ справи в cabinet.court.gov.ua і
перехоплює всі JSON API-виклики, які там робить SPA. Мета — знайти
ендпоінт з датою призначеного судового засідання (на сторінці списку
справ /api/cases/my цих даних немає).

Використання:
    python3 debug_case_detail.py /шлях/до/ключа.jks ВашПароль [case_id]

Якщо case_id не вказано — візьме перший case_id зі списку "Моїх справ".
"""

import asyncio
import json
import sys
from pathlib import Path

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

from app.cabinet_auth import get_session, clear_session, apply_session

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

API_CALLS = []


def make_response_logger():
    async def on_response(response):
        try:
            req = response.request
            if req.resource_type not in ("xhr", "fetch"):
                return
            ctype = response.headers.get("content-type", "")
            if "json" not in ctype:
                return
            try:
                body = await response.text()
            except Exception:
                body = ""
            entry = {
                "method": req.method,
                "url": response.url,
                "status": response.status,
                "body": body,  # повний, без обрізання — саме тут шукаємо дату засідання
            }
            API_CALLS.append(entry)
            print(f"  [api] {req.method} {response.status} {response.url}")
        except Exception as e:
            print(f"  [api] помилка логування відповіді: {e}")
    return on_response


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 debug_case_detail.py /шлях/до/ключа.jks ВашПароль [case_id]")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = " ".join(sys.argv[2:]) if len(sys.argv) == 3 else " ".join(sys.argv[2:-1])
    case_id = sys.argv[-1] if len(sys.argv) > 3 and len(sys.argv[-1]) > 20 else None

    print("[1] Авторизуюсь (використає кешовану сесію, якщо свіжа)...")
    session = await get_session(kep_file, password)
    print(f"[OK] Отримано {len(session['cookies'])} cookies\n")

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

        # Пряма навігація на /cases/<id> редиректить назад на список (перевірено),
        # тому деталі відкриваємо як користувач: виділяємо рядок у таблиці і
        # натискаємо кнопку "ІНФОРМАЦІЯ ПРО СПРАВУ" над нею.
        print("[2] Відкриваю список справ...")
        await page.goto("https://cabinet.court.gov.ua/cases", wait_until="networkidle", timeout=30_000)
        try:
            row = await page.wait_for_selector("tr[id='cases-row-0']", timeout=20_000)
        except PWTimeout:
            row = None
        if not row:
            print("  ПОМИЛКА: не знайшов рядків у таблиці справ за 20с")
            await page.screenshot(path=str(OUT / "case_detail_fail.png"), full_page=True)
            await browser.close()
            return

        print("  Виділяю перший рядок (чекбокс/клік по рядку)...")
        checkbox = await row.query_selector("input[type='checkbox']")
        if checkbox:
            await checkbox.click()
        else:
            await row.click()
        await asyncio.sleep(1)

        print("  Шукаю кнопку 'ІНФОРМАЦІЯ ПРО СПРАВУ'...")
        info_btn = await page.query_selector("text=ІНФОРМАЦІЯ ПРО СПРАВУ")
        if not info_btn:
            info_btn = await page.query_selector("text=Інформація про справу")
        if info_btn:
            print("  Клікаю 'ІНФОРМАЦІЯ ПРО СПРАВУ'...")
            await info_btn.click()
            await asyncio.sleep(5)  # даємо час на завантаження деталей
        else:
            # Може, деталі відкриваються подвійним кліком по рядку
            print("  Кнопку не знайдено, пробую подвійний клік по рядку...")
            await row.dblclick()
            await asyncio.sleep(5)

        await page.screenshot(path=str(OUT / "case_detail.png"), full_page=True)
        (OUT / "case_detail.html").write_text(await page.content(), encoding="utf-8")
        print(f"\n[3] Модалка 'Інформація про справу' відкрита (URL: {page.url})")

        # У модалці є кнопка "ДОКУМЕНТИ ПО СПРАВІ" — саме вона, найімовірніше,
        # веде на список документів (ухвали, повістки з датами засідань).
        docs_btn = await page.query_selector("text=ДОКУМЕНТИ ПО СПРАВІ")
        if not docs_btn:
            docs_btn = await page.query_selector("text=Документи по справі")
        if docs_btn:
            print("[4] Натискаю 'ДОКУМЕНТИ ПО СПРАВІ'...")
            await docs_btn.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(4)
            print(f"    Після кліку URL: {page.url}")
            await page.screenshot(path=str(OUT / "case_documents.png"), full_page=True)
            (OUT / "case_documents.html").write_text(await page.content(), encoding="utf-8")
        else:
            print("[4] Кнопку 'ДОКУМЕНТИ ПО СПРАВІ' не знайдено")

        await browser.close()

    (OUT / "case_detail_api_calls.json").write_text(
        json.dumps(API_CALLS, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n[4] Перехоплено {len(API_CALLS)} JSON-викликів. Шукаю згадки про засідання/дату...")
    for c in API_CALLS:
        body_lower = c["body"].lower()
        hints = ["hearing", "засідан", "schedule", "розгляд", "призначен"]
        if any(h in body_lower for h in hints) or any(h in c["url"].lower() for h in hints):
            print(f"  ЙМОВІРНО РЕЛЕВАНТНО: {c['method']} {c['url']}")
        else:
            print(f"  {c['method']} {c['status']} {c['url']}")

    print("\nГотово! Повний вивід: debug_output/case_detail_api_calls.json")
    print("Скриншот: debug_output/case_detail.png")


asyncio.run(main())

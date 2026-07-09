"""
Debug: відкриває документи по справі, клікає на перший документ і
перехоплює запити — щоб знайти ендпоінт завантаження/перегляду файлу
(PDF рішення тощо) та зрозуміти, як він захищений.

Використання:
    python3 debug_document_download.py /шлях/до/ключа.jks ВашПароль [case_id]

case_id за замовчуванням — справа 754/8443/26.
"""

import asyncio
import json
import sys
from pathlib import Path

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

from app.cabinet_auth import get_session, clear_session, apply_session

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

DEFAULT_CASE_ID = "019e0a11a6b37a64b49d80d119827ced"

API_CALLS = []


def make_response_logger():
    async def on_response(response):
        try:
            req = response.request
            url = response.url
            ctype = response.headers.get("content-type", "")
            # Логуємо і JSON, і файли (pdf/octet-stream/zip)
            interesting = (
                req.resource_type in ("xhr", "fetch")
                or "pdf" in ctype
                or "octet-stream" in ctype
                or "zip" in ctype
                or "/download" in url
                or "/storage" in url
                or "/file" in url.lower()
            )
            if not interesting:
                return
            body_preview = ""
            if "json" in ctype:
                try:
                    body_preview = (await response.text())[:1500]
                except Exception:
                    body_preview = ""
            API_CALLS.append({
                "method": req.method,
                "url": url,
                "status": response.status,
                "content_type": ctype,
                "body_preview": body_preview,
            })
            print(f"  [api] {req.method} {response.status} [{ctype[:30]}] {url[:110]}")
        except Exception as e:
            print(f"  [api] помилка: {e}")
    return on_response


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 debug_document_download.py /шлях/до/ключа.jks ВашПароль [case_id]")
        sys.exit(1)

    kep_file = sys.argv[1]
    # case_id — останній аргумент, якщо він схожий на id (довгий)
    if len(sys.argv) > 3 and len(sys.argv[-1]) > 20:
        case_id = sys.argv[-1]
        password = " ".join(sys.argv[2:-1])
    else:
        case_id = DEFAULT_CASE_ID
        password = " ".join(sys.argv[2:])

    print(f"[1] Авторизуюсь... (справа {case_id})")
    session = await get_session(kep_file, password)
    print(f"[OK] {len(session['cookies'])} cookies\n")

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
            accept_downloads=True,
        )
        await apply_session(context, session)
        page = await context.new_page()
        page.on("response", make_response_logger())

        # Перехоплюємо спробу завантаження файлу
        downloads = []
        page.on("download", lambda d: downloads.append(d))

        print("[2] Відкриваю сторінку документів по справі напряму...")
        await page.goto(
            f"https://cabinet.court.gov.ua/cases/case={case_id}/documents",
            wait_until="networkidle",
            timeout=30_000,
        )
        await asyncio.sleep(4)

        # Чекаємо рядки таблиці документів
        try:
            row = await page.wait_for_selector("tbody tr", timeout=15_000)
        except PWTimeout:
            row = None
        if not row:
            print("  ПОМИЛКА: таблиця документів не з'явилась")
            await page.screenshot(path=str(OUT / "doc_download_fail.png"), full_page=True)
            await browser.close()
            return

        print("[3] Клікаю на перший документ...")
        await row.click()
        await asyncio.sleep(4)
        await page.screenshot(path=str(OUT / "doc_opened.png"), full_page=True)
        (OUT / "doc_opened.html").write_text(await page.content(), encoding="utf-8")

        # Шукаємо кнопки завантаження/перегляду
        for text in ["Завантажити", "Переглянути", "Скачати", "Відкрити", "Документ"]:
            btn = await page.query_selector(f"text={text}")
            if btn:
                print(f"[4] Знайдено кнопку '{text}' — клікаю...")
                try:
                    await btn.click()
                    await asyncio.sleep(4)
                except Exception as e:
                    print(f"    (не вдалося: {e})")
                break

        await asyncio.sleep(2)
        if downloads:
            print(f"\n[5] Перехоплено {len(downloads)} завантажень:")
            for d in downloads:
                print(f"    URL: {d.url}")
                print(f"    Ім'я файлу: {d.suggested_filename}")

        await browser.close()

    (OUT / "doc_download_api_calls.json").write_text(
        json.dumps(API_CALLS, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"\n[6] Перехоплено {len(API_CALLS)} запитів (див. debug_output/doc_download_api_calls.json)")
    for c in API_CALLS:
        hints = ["file", "download", "storage", "attach", "pdf", "content"]
        mark = "  >>> " if any(h in c["url"].lower() for h in hints) else "      "
        print(f"{mark}{c['method']} {c['status']} [{c['content_type'][:25]}] {c['url'][:100]}")

    print("\nГотово! Скриншот: debug_output/doc_opened.png")


asyncio.run(main())

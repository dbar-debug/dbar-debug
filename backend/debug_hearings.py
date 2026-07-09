"""
Debug: шукає дату/час судового засідання за номером справи з відкритих
даних "Список справ призначених до розгляду".

Пробує два шляхи:
  1) CKAN datastore_search API на data.gov.ua (пошук у CSV без завантаження);
  2) веб-пошук на court.gov.ua/csz/ через Playwright + лог мережевих запитів.

Використання:
    python3 debug_hearings.py "754/8443/26"
"""

import asyncio
import json
import sys
from pathlib import Path

import urllib.request
import urllib.parse

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

# Ресурс "Список справ призначених до розгляду" на data.gov.ua
DATASET_ID = "42eaff6e-45da-4426-b4a1-f30989bfd36f"
RESOURCE_ID = "98d6ba0d-1c18-4835-ae68-bfc0af724bfa"

CSZ_URL = "https://court.gov.ua/assignments/"


def try_ckan(case_number: str):
    print("\n[A] Пробую CKAN datastore_search API...")
    base = "https://data.gov.ua/api/3/action"

    # 1. package_show — список ресурсів і чи є datastore
    try:
        url = f"{base}/package_show?id={DATASET_ID}"
        with urllib.request.urlopen(url, timeout=30) as r:
            data = json.loads(r.read().decode("utf-8"))
        resources = data.get("result", {}).get("resources", [])
        print(f"  Ресурсів у датасеті: {len(resources)}")
        for res in resources:
            print(f"    - {res.get('name')} | format={res.get('format')} | "
                  f"datastore_active={res.get('datastore_active')} | id={res.get('id')}")
            print(f"      url: {res.get('url')}")
    except Exception as e:
        print(f"  package_show помилка: {e}")

    # 2. datastore_search з фільтром по номеру справи
    for res_id in [RESOURCE_ID]:
        try:
            q = urllib.parse.quote(case_number)
            url = f"{base}/datastore_search?resource_id={res_id}&q={q}&limit=5"
            with urllib.request.urlopen(url, timeout=30) as r:
                data = json.loads(r.read().decode("utf-8"))
            records = data.get("result", {}).get("records", [])
            print(f"  datastore_search({res_id}): {len(records)} записів")
            for rec in records[:5]:
                print(f"    {rec}")
            if data.get("result", {}).get("fields"):
                print(f"  Поля: {[f['id'] for f in data['result']['fields']]}")
        except Exception as e:
            print(f"  datastore_search помилка: {e}")


async def try_web(case_number: str):
    print("\n[B] Пробую веб-пошук court.gov.ua/assignments/ ...")
    api_calls = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True, args=["--no-sandbox"])
        page = await browser.new_page(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="uk-UA",
        )

        async def on_response(resp):
            try:
                if resp.request.resource_type in ("xhr", "fetch"):
                    ctype = resp.headers.get("content-type", "")
                    body = ""
                    if "json" in ctype:
                        try:
                            body = (await resp.text())[:1500]
                        except Exception:
                            body = ""
                    api_calls.append({"url": resp.url, "status": resp.status, "body": body})
                    print(f"  [api] {resp.request.method} {resp.status} {resp.url[:110]}")
            except Exception:
                pass
        page.on("response", on_response)

        try:
            await page.goto(CSZ_URL, wait_until="networkidle", timeout=30_000)
        except PWTimeout:
            pass
        await asyncio.sleep(2)
        await page.screenshot(path=str(OUT / "hearings_1_form.png"), full_page=True)

        # Показати поля вводу
        inputs = await page.evaluate("""() => Array.from(document.querySelectorAll('input,select,textarea'))
            .map(e => ({tag:e.tagName,id:e.id,name:e.name,type:e.type,ph:e.placeholder}))""")
        print("  Поля форми:")
        for i in inputs:
            print(f"    {i}")

        # Спробувати ввести номер справи в перше текстове поле і сабмітнути
        text_input = await page.query_selector("input[type='text'], input:not([type])")
        if text_input:
            await text_input.fill(case_number)
            await asyncio.sleep(0.5)
            # Шукаємо кнопку пошуку
            btn = await page.query_selector("button[type='submit'], input[type='submit'], button, .btn")
            if btn:
                await btn.click()
            else:
                await text_input.press("Enter")
            try:
                await page.wait_for_load_state("networkidle", timeout=20_000)
            except PWTimeout:
                pass
            await asyncio.sleep(3)
            print(f"  URL після пошуку: {page.url}")

        await page.screenshot(path=str(OUT / "hearings_2_results.png"), full_page=True)
        (OUT / "hearings_results.html").write_text(await page.content(), encoding="utf-8")

        # Аналіз результатів
        info = await page.evaluate("""() => {
            const rows = document.querySelectorAll('tr, .result, .case-item');
            return {
                rows: rows.length,
                bodyText: document.body.innerText.slice(0, 600),
                firstRows: Array.from(document.querySelectorAll('tr')).slice(0,5).map(r=>r.innerText.slice(0,200))
            };
        }""")
        print(f"\n  Рядків: {info['rows']}")
        print(f"  Текст сторінки:\n  {info['bodyText']}")
        print("\n  Перші рядки:")
        for r in info["firstRows"]:
            print(f"    {r}")

        await browser.close()

    (OUT / "hearings_api_calls.json").write_text(
        json.dumps(api_calls, ensure_ascii=False, indent=2), encoding="utf-8"
    )


async def main():
    case_number = sys.argv[1] if len(sys.argv) > 1 else "754/8443/26"
    print(f"Шукаю засідання для справи: {case_number}")

    try_ckan(case_number)
    await try_web(case_number)

    print("\nГотово! Скриншоти: debug_output/hearings_1_form.png, hearings_2_results.png")
    print("Мережеві виклики: debug_output/hearings_api_calls.json")


asyncio.run(main())

"""
Debug script v5: follow full auth flow through id.gov.ua
Run: python3 debug_cabinet.py
"""

import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

OUT_DIR = Path("debug_output")
OUT_DIR.mkdir(exist_ok=True)

LOGIN_URL = "https://cabinet.court.gov.ua/login"


async def snapshot(page, name: str):
    await page.screenshot(path=str(OUT_DIR / f"{name}.png"), full_page=True)
    (OUT_DIR / f"{name}.html").write_text(await page.content(), encoding="utf-8")
    print(f"  [saved] {name}.png  |  URL: {page.url}")


async def print_buttons(page, label: str):
    print(f"\n  Кнопки/посилання ({label}):")
    for frame in page.frames:
        els = await frame.query_selector_all("a, button, [role='button']")
        for el in els:
            text = (await el.inner_text()).strip()[:60]
            href = await el.get_attribute("href") or ""
            cls  = await el.get_attribute("class") or ""
            eid  = await el.get_attribute("id") or ""
            if text and text not in ("Close", "Ok", "Увімкніть звук", ""):
                print(f"    id='{eid}' text='{text}' href='{href[:60]}'")


async def main():
    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        page = await browser.new_page(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            locale="uk-UA",
        )
        page.on("framenavigated", lambda f: print(f"  >> {f.url[:90]}"))

        # ── Крок 1: cabinet.court.gov.ua/login ──────────────────────────
        print("\n[1] cabinet.court.gov.ua/login")
        await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(2)

        link = await page.query_selector("a[href*='redirect']")
        if link:
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(2)
        await snapshot(page, "s1_id_court")

        # ── Крок 2: id.court.gov.ua — клік "Авторизуватись з id.gov.ua" ─
        print("\n[2] Клікаю 'Авторизуватись з id.gov.ua' ...")
        btn = await page.query_selector("#AuthIdGov-button")
        if btn:
            await btn.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)
        await snapshot(page, "s2_id_gov_ua")
        print(f"  URL: {page.url}")

        # ── Крок 3: Що є на id.gov.ua ────────────────────────────────────
        print("\n[3] Варіанти авторизації на id.gov.ua:")
        body = await page.inner_text("body")
        for line in body.splitlines():
            line = line.strip()
            if line:
                print(f"  {line}")

        await print_buttons(page, "id.gov.ua")

        # ── Крок 4: Шукаємо варіант КЕП / ПриватБанк / BankID ──────────
        print("\n[4] Шукаю КЕП / BankID / ПриватБанк ...")
        kw = ["кеп", "ключ", "файл", "приват", "bankid", "bank id",
              "підпис", "token", "носій", "смарт", "хмарний", "дія"]
        for frame in page.frames:
            els = await frame.query_selector_all("a, button, div, li, span, label")
            for el in els:
                text = (await el.inner_text()).strip().lower()
                if any(k in text for k in kw) and 2 < len(text) < 100:
                    tag  = await el.evaluate("e => e.tagName")
                    href = await el.get_attribute("href") or ""
                    eid  = await el.get_attribute("id") or ""
                    print(f"  <{tag}> id='{eid}' text='{text}' href='{href[:60]}'")

        await browser.close()
    print("\nГотово! Перегляньте debug_output/s2_id_gov_ua.png")


asyncio.run(main())

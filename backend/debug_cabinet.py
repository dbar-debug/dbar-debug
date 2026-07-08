"""
Debug script v6: go all the way to the IIT EUSign file widget.
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
        page.on("framenavigated", lambda f: print(f"  >> {f.url[:100]}"))

        # ── 1. cabinet → id.court.gov.ua ────────────────────────────────
        print("\n[1] Відкриваю cabinet.court.gov.ua/login ...")
        await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(2)
        link = await page.query_selector("a[href*='redirect']")
        if link:
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(2)

        # ── 2. id.court.gov.ua → id.gov.ua ─────────────────────────────
        print("\n[2] Клікаю 'Авторизуватись з id.gov.ua' ...")
        btn = await page.query_selector("#AuthIdGov-button")
        if btn:
            await btn.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)

        # ── 3. Закрити cookie-банер (якщо є) ────────────────────────────
        print("\n[3] Закриваю cookie-банер ...")
        cookie_btn = await page.query_selector("#CybotCookiebotDialogBodyButtonAccept")
        if cookie_btn:
            await cookie_btn.click()
            await asyncio.sleep(1)
            print("  Cookie-банер закрито")
        else:
            print("  Cookie-банер не знайдено")

        await snapshot(page, "s3_id_gov_ua_clean")

        # ── 4. Клікнути "Файловий носій" ────────────────────────────────
        print("\n[4] Клікаю 'Файловий носій' ...")
        file_link = await page.query_selector("a[href='/euid-auth-js']")
        if file_link:
            await file_link.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(4)
        else:
            print("  Посилання не знайдено, пробую за текстом...")
            for el in await page.query_selector_all("a"):
                text = (await el.inner_text()).strip().lower()
                if "файловий" in text:
                    await el.click()
                    await page.wait_for_load_state("networkidle", timeout=20_000)
                    await asyncio.sleep(4)
                    break

        await snapshot(page, "s4_euid_widget")
        print(f"\n  URL після кліку: {page.url}")

        # ── 5. Що є на сторінці IIT widget ──────────────────────────────
        print("\n[5] Текст на сторінці IIT widget:")
        body = await page.inner_text("body")
        for line in body.splitlines():
            line = line.strip()
            if line:
                print(f"  {line}")

        print(f"\n[6] Фреймів: {len(page.frames)}")
        for i, f in enumerate(page.frames):
            print(f"  [{i}] {f.url}")

        print("\n[7] Input-поля (всі фрейми):")
        for frame in page.frames:
            inputs = await frame.query_selector_all("input, button, [type='file']")
            if inputs:
                print(f"  --- frame: {frame.url[:70]} ---")
                for el in inputs:
                    attrs = {}
                    for a in ["type", "id", "name", "class", "placeholder", "accept"]:
                        v = await el.get_attribute(a)
                        if v:
                            attrs[a] = v[:60]
                    txt = (await el.inner_text()).strip()[:40]
                    if txt:
                        attrs["text"] = txt
                    print(f"    {attrs}")

        await browser.close()
    print("\nГотово! Перегляньте debug_output/s4_euid_widget.png")


asyncio.run(main())

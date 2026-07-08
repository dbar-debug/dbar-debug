"""
Debug script: inspects cabinet.court.gov.ua login page structure
to find the IIT SignWidget and understand the KEP auth flow.

Run: python3 debug_cabinet.py
"""

import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

OUT_DIR = Path("debug_output")
OUT_DIR.mkdir(exist_ok=True)

CABINET_URL = "https://cabinet.court.gov.ua"


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

        # ── 1. Головна / сторінка входу ──────────────────────────────────
        print(f"[1] Відкриваю {CABINET_URL} ...")
        await page.goto(CABINET_URL, wait_until="networkidle", timeout=30_000)

        await page.screenshot(path=str(OUT_DIR / "3_cabinet_home.png"), full_page=True)
        (OUT_DIR / "3_cabinet_home.html").write_text(await page.content(), encoding="utf-8")
        print(f"    URL: {page.url}")
        print("    Збережено: debug_output/3_cabinet_home.png")

        # ── 2. Всі iframe на сторінці (IIT widget зазвичай в iframe) ─────
        frames = page.frames
        print(f"\n[2] Знайдено фреймів: {len(frames)}")
        for i, frame in enumerate(frames):
            print(f"    [{i}] url={frame.url}  name={frame.name}")

        # ── 3. Кнопки входу ───────────────────────────────────────────────
        print("\n[3] Кнопки / посилання входу:")
        login_els = await page.query_selector_all(
            "a[href*='login'], a[href*='auth'], button[class*='login'], "
            "a[class*='login'], a[class*='enter'], button[class*='sign']"
        )
        for el in login_els:
            tag  = await el.evaluate("e => e.tagName")
            text = (await el.inner_text()).strip()[:60]
            href = await el.get_attribute("href") or ""
            print(f"    <{tag}> '{text}' href='{href}'")

        # ── 4. Клікнути кнопку "УВІЙТИ" ──────────────────────────────────
        print("\n[4] Шукаю кнопку 'УВІЙТИ' ...")
        btn_selectors = [
            "button", "a.btn", "[class*='login']", "[class*='enter']",
            "[class*='signin']", "[class*='auth']",
        ]
        clicked = False
        for sel in btn_selectors:
            els = await page.query_selector_all(sel)
            for el in els:
                text = (await el.inner_text()).strip().upper()
                if any(w in text for w in ["УВІЙТИ", "ВХІД", "ВОЙТИ", "LOGIN", "SIGN IN", "ENTER"]):
                    print(f"    Клікаю: '{text}' (селектор: {sel})")
                    await el.click()
                    clicked = True
                    break
            if clicked:
                break

        if not clicked:
            print("    Кнопку не знайдено — пробую клікнути перший button")
            btn = await page.query_selector("button")
            if btn:
                await btn.click()
                clicked = True

        if clicked:
            print("    Чекаю завантаження widget...")
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)  # додатковий час для JS

            await page.screenshot(path=str(OUT_DIR / "4_after_login_click.png"), full_page=True)
            (OUT_DIR / "4_after_login_click.html").write_text(await page.content(), encoding="utf-8")
            print("    Збережено: debug_output/4_after_login_click.png")
            print(f"    URL: {page.url}")

        # ── 5. Всі фрейми після кліку ─────────────────────────────────────
        print(f"\n[5] Фреймів після кліку: {len(page.frames)}")
        for i, frame in enumerate(page.frames):
            print(f"    [{i}] url={frame.url}  name={frame.name}")

        # ── 6. Всі input та button на сторінці і в фреймах ───────────────
        print("\n[6] Input/button елементи (основна сторінка + всі фрейми):")
        for frame in page.frames:
            els = await frame.query_selector_all("input, button, [role='button']")
            if not els:
                continue
            print(f"  --- frame: {frame.url[:80]} ---")
            for el in els:
                attrs = {}
                for attr in ["type", "id", "class", "placeholder", "name"]:
                    v = await el.get_attribute(attr)
                    if v:
                        attrs[attr] = v[:50]
                text = (await el.inner_text()).strip()[:40]
                if text:
                    attrs["text"] = text
                print(f"    {attrs}")

        # ── 7. Всі видимі тексти на сторінці ─────────────────────────────
        print("\n[7] Видимий текст на сторінці (перші 50 рядків):")
        body_text = await page.inner_text("body")
        lines = [l.strip() for l in body_text.splitlines() if l.strip()]
        for line in lines[:50]:
            print(f"    {line}")

        await browser.close()

    print("\nГотово! Відкрийте debug_output/4_after_login_click.png")


asyncio.run(main())

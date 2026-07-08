"""
Debug script v2: step-by-step inspection of cabinet.court.gov.ua
Run: python3 debug_cabinet.py
"""

import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

OUT_DIR = Path("debug_output")
OUT_DIR.mkdir(exist_ok=True)

CABINET_URL = "https://cabinet.court.gov.ua/login"


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

        # ── 1. Відкрити сторінку ─────────────────────────────────────────
        print(f"[1] Відкриваю {CABINET_URL}")
        await page.goto(CABINET_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(5)  # чекаємо React

        await page.screenshot(path=str(OUT_DIR / "step1_loaded.png"), full_page=True)
        print(f"    URL: {page.url}")
        print("    Збережено: step1_loaded.png")

        # ── 2. Всі кнопки ───────────────────────────────────────────────
        print("\n[2] Всі кнопки на сторінці:")
        buttons = await page.query_selector_all("button, a, [role='button']")
        for i, btn in enumerate(buttons):
            text = (await btn.inner_text()).strip()
            cls = await btn.get_attribute("class") or ""
            href = await btn.get_attribute("href") or ""
            if text or href:
                print(f"    [{i}] text='{text[:50]}' class='{cls[:40]}' href='{href[:40]}'")

        # ── 3. Весь текст сторінки ───────────────────────────────────────
        print("\n[3] Весь видимий текст:")
        try:
            body = await page.inner_text("body")
            for line in body.splitlines():
                line = line.strip()
                if line:
                    print(f"    {line}")
        except Exception as e:
            print(f"    Помилка: {e}")

        # ── 4. Клікнути перший button ────────────────────────────────────
        print("\n[4] Клікаю перший button...")
        try:
            first_btn = await page.query_selector("button")
            if first_btn:
                text = (await first_btn.inner_text()).strip()
                print(f"    Кнопка: '{text}'")
                await first_btn.click()
                await asyncio.sleep(5)

                await page.screenshot(path=str(OUT_DIR / "step4_after_click.png"), full_page=True)
                (OUT_DIR / "step4_after_click.html").write_text(
                    await page.content(), encoding="utf-8"
                )
                print("    Збережено: step4_after_click.png + .html")
                print(f"    URL після кліку: {page.url}")

                # Фрейми після кліку
                print(f"\n[5] Фреймів після кліку: {len(page.frames)}")
                for i, f in enumerate(page.frames):
                    print(f"    [{i}] {f.url}")

                # Всі input після кліку
                print("\n[6] Всі input/button після кліку:")
                for frame in page.frames:
                    els = await frame.query_selector_all("input, button")
                    if els:
                        print(f"  --- frame: {frame.url[:70]} ---")
                        for el in els:
                            attrs = {}
                            for attr in ["type", "id", "class", "placeholder", "name"]:
                                v = await el.get_attribute(attr)
                                if v:
                                    attrs[attr] = v[:50]
                            txt = (await el.inner_text()).strip()[:40]
                            if txt:
                                attrs["text"] = txt
                            print(f"      {attrs}")

                print("\n[7] Текст після кліку:")
                body = await page.inner_text("body")
                for line in body.splitlines():
                    line = line.strip()
                    if line:
                        print(f"    {line}")
            else:
                print("    Жодної кнопки не знайдено!")
        except Exception as e:
            print(f"    Помилка при кліку: {e}")

        await browser.close()
    print("\nГотово!")


asyncio.run(main())

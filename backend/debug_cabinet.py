"""
Debug script v4: click the <a> "УВІЙТИ" link and follow all redirects.
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
    print(f"  Збережено: {name}.png  |  URL: {page.url}")


async def print_info(page, label: str):
    print(f"\n=== {label} ===")
    print(f"URL: {page.url}")

    body = ""
    try:
        body = await page.inner_text("body")
    except Exception:
        pass
    lines = [l.strip() for l in body.splitlines() if l.strip()]
    print(f"Текст ({len(lines)} рядків):")
    for l in lines[:30]:
        print(f"  {l}")

    print(f"Фреймів: {len(page.frames)}")
    for i, f in enumerate(page.frames):
        print(f"  [{i}] {f.url}")

    print("Всі <a> та <button>:")
    for frame in page.frames:
        for el in await frame.query_selector_all("a, button"):
            text = (await el.inner_text()).strip()[:60]
            href = await el.get_attribute("href") or ""
            cls  = await el.get_attribute("class") or ""
            if text or href:
                print(f"  text='{text}' href='{href[:80]}' cls='{cls[:30]}'")

    print("Всі <input>:")
    for frame in page.frames:
        for inp in await frame.query_selector_all("input"):
            attrs = {}
            for a in ["type", "id", "name", "placeholder", "class"]:
                v = await inp.get_attribute(a)
                if v:
                    attrs[a] = v[:50]
            print(f"  {attrs}")


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

        # Логувати всі навігації
        page.on("framenavigated", lambda f: print(f"  >> навігація: {f.url}"))

        # ── 1. Відкрити сторінку входу ───────────────────────────────────
        print(f"[1] Відкриваю {LOGIN_URL}")
        await page.goto(LOGIN_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(3)
        await snapshot(page, "s1_login")

        # ── 2. Знайти і клікнути <a> з текстом УВІЙТИ ───────────────────
        print("\n[2] Шукаю посилання УВІЙТИ...")
        link = None
        for el in await page.query_selector_all("a"):
            text = (await el.inner_text()).strip().upper()
            if "УВІЙТИ" in text or "ВОЙТИ" in text or "LOGIN" in text.upper():
                link = el
                print(f"  Знайдено: '{text}'  href='{await el.get_attribute('href')}'")
                break

        if not link:
            # Запасний варіант — перший видимий елемент з href
            print("  Не знайдено по тексту, клікаю перший <a> з href...")
            for el in await page.query_selector_all("a[href]"):
                href = await el.get_attribute("href") or ""
                if href and href != "#" and "tel:" not in href:
                    link = el
                    print(f"  href='{href}'")
                    break

        if link:
            print("\n[3] Клікаю посилання і стежу за редиректами...")
            await link.click()
            # Чекаємо до 15 секунд поки сторінка стабілізується
            try:
                await page.wait_for_load_state("networkidle", timeout=15_000)
            except Exception:
                pass
            await asyncio.sleep(3)
            await snapshot(page, "s2_after_click")
            await print_info(page, "Після кліку УВІЙТИ")

            # ── 4. Якщо відкрилась нова сторінка ─────────────────────────
            current_url = page.url
            if "court.gov.ua" not in current_url:
                print(f"\n[4] Перейшли на зовнішній сервіс: {current_url}")
                await asyncio.sleep(3)
                await snapshot(page, "s3_external_auth")
                await print_info(page, "Зовнішній сервіс авторизації")
        else:
            print("  Жодного посилання не знайдено!")

        await browser.close()
    print("\nГотово!")


asyncio.run(main())

"""
Debug script v3: follow the /redirect/au auth flow on cabinet.court.gov.ua
Run: python3 debug_cabinet.py
"""

import asyncio
from pathlib import Path
from playwright.async_api import async_playwright

OUT_DIR = Path("debug_output")
OUT_DIR.mkdir(exist_ok=True)

AUTH_URL = "https://cabinet.court.gov.ua/redirect/au"


async def snapshot(page, name: str):
    path_png  = str(OUT_DIR / f"{name}.png")
    path_html = str(OUT_DIR / f"{name}.html")
    await page.screenshot(path=path_png, full_page=True)
    (OUT_DIR / f"{name}.html").write_text(await page.content(), encoding="utf-8")
    print(f"    Збережено: {name}.png  |  URL: {page.url}")


async def print_page_info(page, label: str):
    print(f"\n--- {label} ---")
    print(f"URL: {page.url}")

    # Текст
    try:
        body = await page.inner_text("body")
        lines = [l.strip() for l in body.splitlines() if l.strip()]
        print("Текст:")
        for l in lines[:40]:
            print(f"  {l}")
    except Exception:
        pass

    # Фрейми
    print(f"Фреймів: {len(page.frames)}")
    for i, f in enumerate(page.frames):
        print(f"  [{i}] {f.url}")

    # Всі посилання та кнопки
    print("Посилання/кнопки:")
    for frame in page.frames:
        els = await frame.query_selector_all("a, button, [role='button']")
        for el in els:
            text = (await el.inner_text()).strip()[:50]
            href = await el.get_attribute("href") or ""
            cls  = await el.get_attribute("class") or ""
            if text or href:
                print(f"  text='{text}' href='{href[:60]}' class='{cls[:30]}'")

    # Input-поля
    print("Input-поля:")
    for frame in page.frames:
        inputs = await frame.query_selector_all("input")
        for inp in inputs:
            attrs = {}
            for attr in ["type", "id", "name", "class", "placeholder"]:
                v = await inp.get_attribute(attr)
                if v:
                    attrs[attr] = v[:50]
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

        # ── 1. Перейти напряму на /redirect/au ──────────────────────────
        print(f"[1] Відкриваю {AUTH_URL}")
        await page.goto(AUTH_URL, wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(4)
        await snapshot(page, "step1_redirect_au")
        await print_page_info(page, "Після /redirect/au")

        # ── 2. Якщо перенаправило — ще один крок ────────────────────────
        if page.url != AUTH_URL:
            print(f"\n[2] Перенаправило на: {page.url}")
            await asyncio.sleep(3)
            await snapshot(page, "step2_after_redirect")
            await print_page_info(page, "Після редиректу")

            # Шукаємо кнопку "КЕП" або "Файловий носій" або "ПриватБанк"
            print("\n[3] Шукаю варіанти входу (КЕП, ключ, файл):")
            kw = ["кеп", "ключ", "файл", "приват", "eds", "sign", "token",
                  "носій", "смарт", "smart", "usb", "mobile", "дія", "diia"]
            for frame in page.frames:
                els = await frame.query_selector_all("a, button, div, li, span")
                for el in els:
                    text = (await el.inner_text()).strip().lower()
                    if any(k in text for k in kw) and len(text) < 80:
                        tag  = await el.evaluate("e => e.tagName")
                        href = await el.get_attribute("href") or ""
                        print(f"  <{tag}> '{text}' href='{href}'")

        await browser.close()
    print("\nГотово! Перегляньте скриншоти в debug_output/")


asyncio.run(main())

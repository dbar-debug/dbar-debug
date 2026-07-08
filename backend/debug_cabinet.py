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

        # ── 4. Перейти на сторінку авторизації якщо є окремий шлях ──────
        auth_urls = ["/login", "/auth", "/sign-in", "/enter"]
        for path in auth_urls:
            try:
                resp = await page.goto(f"{CABINET_URL}{path}", wait_until="networkidle", timeout=10_000)
                if resp and resp.status == 200:
                    print(f"\n[4] Знайдено сторінку авторизації: {CABINET_URL}{path}")
                    await page.screenshot(
                        path=str(OUT_DIR / f"4_cabinet_login{path.replace('/', '_')}.png"),
                        full_page=True,
                    )
                    (OUT_DIR / f"4_cabinet_login{path.replace('/', '_')}.html").write_text(
                        await page.content(), encoding="utf-8"
                    )

                    # Iframe на сторінці входу
                    frames = page.frames
                    print(f"    Фреймів на цій сторінці: {len(frames)}")
                    for i, frame in enumerate(frames):
                        print(f"    [{i}] {frame.url}")
                    break
            except Exception:
                pass

        # ── 5. Пошук IIT SignWidget (зазвичай iframe від eu.iit.com.ua) ──
        print("\n[5] Шукаю IIT SignWidget ...")
        iit_frames = [f for f in page.frames if "iit" in f.url.lower() or "sign" in f.url.lower()]
        if iit_frames:
            for f in iit_frames:
                print(f"    Знайдено IIT frame: {f.url}")
                inputs = await f.query_selector_all("input, button")
                for el in inputs:
                    attrs = {}
                    for attr in ["type", "id", "class", "placeholder"]:
                        v = await el.get_attribute(attr)
                        if v:
                            attrs[attr] = v
                    print(f"      {attrs}")
        else:
            print("    IIT frame не знайдено на поточній сторінці")

        await browser.close()

    print("\nГотово! Відкрийте debug_output/3_cabinet_home.png")
    print("та debug_output/4_cabinet_login_*.png")


asyncio.run(main())

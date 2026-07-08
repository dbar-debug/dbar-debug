"""
Тест авторизації через КЕП з debug-скриншотами на кожному кроці.
Використання:
    python3 test_cabinet_auth.py /шлях/до/ключа.jks ВашПароль
"""

import asyncio
import sys
from pathlib import Path
from playwright.async_api import async_playwright, TimeoutError as PWTimeout

OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

PRIVAT_CA = 'КНЕДП АЦСК АТ КБ "ПРИВАТБАНК"'


async def snap(page, name):
    path = str(OUT / f"auth_{name}.png")
    await page.screenshot(path=path, full_page=True)
    (OUT / f"auth_{name}.html").write_text(await page.content(), encoding="utf-8")
    print(f"  [screenshot] auth_{name}.png  |  url: {page.url}")


async def get_text(page):
    try:
        t = await page.inner_text("body")
        return " | ".join(l.strip() for l in t.splitlines() if l.strip())[:300]
    except Exception:
        return ""


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 test_cabinet_auth.py /шлях/до/ключа.jks ВашПароль")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = " ".join(sys.argv[2:])   # дозволяє пароль з пробілами
    print(f"Файл: {kep_file}")
    print(f"Пароль: {'*' * len(password)} ({len(password)} символів)")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        page = await browser.new_page(
            user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            locale="uk-UA",
        )
        page.on("framenavigated", lambda f: print(f"  >> {f.url[:100]}"))

        # ── 1. cabinet.court.gov.ua → id.court.gov.ua ────────────────────
        print("\n[1] cabinet.court.gov.ua ...")
        await page.goto("https://cabinet.court.gov.ua/login", wait_until="domcontentloaded", timeout=30_000)
        await asyncio.sleep(2)
        link = await page.query_selector("a[href*='redirect']")
        if link:
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(2)
        await snap(page, "1_id_court")

        # ── 2. → id.gov.ua ───────────────────────────────────────────────
        print("\n[2] Клікаю 'Авторизуватись з id.gov.ua' ...")
        btn = await page.query_selector("#AuthIdGov-button")
        if btn:
            await btn.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)
        cookie_btn = await page.query_selector("#CybotCookiebotDialogBodyButtonAccept")
        if cookie_btn:
            await cookie_btn.click()
            await asyncio.sleep(1)
        await snap(page, "2_id_gov_ua")

        # ── 3. → /euid-auth-js ───────────────────────────────────────────
        print("\n[3] Клікаю 'Файловий носій' ...")
        fl = await page.query_selector("a[href='/euid-auth-js']")
        if fl:
            await fl.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)
        await snap(page, "3_euid_widget")

        # ── 4. Вибрати АЦСК ──────────────────────────────────────────────
        print(f"\n[4] Вибираю АЦСК: {PRIVAT_CA}")

        # Спробувати native select
        sel_el = await page.query_selector("select")
        if sel_el:
            print("  Знайдено native <select>")
            await page.select_option("select", label=PRIVAT_CA)
        else:
            print("  Native select не знайдено, спробую кастомний dropdown...")
            # Клікнути контейнер dropdown
            dropdown = await page.query_selector(
                "[class*='select'], [class*='Select'], [role='button'][aria-haspopup]"
            )
            if dropdown:
                await dropdown.click()
                await asyncio.sleep(1)
                # Знайти опцію ПриватБанку
                found = False
                for opt in await page.query_selector_all("li, [role='option'], [class*='option']"):
                    text = (await opt.inner_text()).strip()
                    if "ПРИВАТБАНК" in text.upper():
                        print(f"  Клікаю: '{text}'")
                        await opt.click()
                        found = True
                        break
                if not found:
                    print("  УВАГА: ПриватБанк не знайдено в списку!")
            else:
                print("  Dropdown не знайдено")

        await asyncio.sleep(1)
        await snap(page, "4_ca_selected")

        # ── 5. Завантажити файл ───────────────────────────────────────────
        print(f"\n[5] Завантажую файл: {Path(kep_file).name}")
        file_input = await page.query_selector("#PKeyFileInput")
        if file_input:
            await file_input.set_input_files(kep_file)
            await asyncio.sleep(3)   # час для JS щоб прочитати файл
            await snap(page, "5_file_uploaded")
            print(f"  Текст після завантаження: {await get_text(page)[:200]}")
        else:
            print("  ПОМИЛКА: #PKeyFileInput не знайдено!")

        # ── 6. Ввести пароль ──────────────────────────────────────────────
        print(f"\n[6] Вводжу пароль ({len(password)} символів) ...")
        pwd_input = await page.query_selector("#PKeyPassword")
        if pwd_input:
            await pwd_input.fill(password)
            await asyncio.sleep(0.5)
        else:
            print("  ПОМИЛКА: #PKeyPassword не знайдено!")

        await snap(page, "6_password_entered")

        # ── 7. Натиснути Продовжити ───────────────────────────────────────
        print("\n[7] Натискаю 'Продовжити' ...")
        cont_btn = await page.query_selector("#id-app-login-sign-form-file-key-sign-button")
        if cont_btn:
            await cont_btn.click()
        else:
            print("  ПОМИЛКА: кнопка Продовжити не знайдена!")

        # Чекати 15 секунд і перевіряти що відбувається
        for i in range(5):
            await asyncio.sleep(3)
            url = page.url
            text = await get_text(page)
            print(f"  [{i*3+3}с] URL: {url}")
            print(f"       Текст: {text[:200]}")
            if "cabinet.court.gov.ua" in url and "login" not in url:
                print("  Авторизація успішна!")
                break

        await snap(page, "7_after_continue")

        await browser.close()

    print("\nГотово! Перевірте скриншоти в debug_output/auth_*.png")


asyncio.run(main())

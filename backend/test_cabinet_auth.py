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

UA = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


async def snap(page, name):
    path = str(OUT / f"auth_{name}.png")
    await page.screenshot(path=path, full_page=True)
    html = await page.content()
    (OUT / f"auth_{name}.html").write_text(html, encoding="utf-8")
    # Витягнути перші 300 символів тексту
    try:
        body_text = await page.inner_text("body")
        short = " | ".join(l.strip() for l in body_text.splitlines() if l.strip())[:300]
    except Exception:
        short = "(не вдалось прочитати текст)"
    print(f"  [snap] {name} | url={page.url}")
    print(f"         текст: {short}")
    print(f"         html-розмір: {len(html)} байт")


async def wait_and_log(page, label, selector, timeout=10_000):
    """Чекати елемент і повернути його, або None."""
    try:
        el = await page.wait_for_selector(selector, timeout=timeout)
        print(f"  [OK] {label}: знайдено '{selector}'")
        return el
    except PWTimeout:
        print(f"  [TIMEOUT] {label}: '{selector}' не з'явився за {timeout//1000}с")
        # Показати що є на сторінці
        try:
            tags = await page.evaluate("""() => {
                const els = document.querySelectorAll('a, button, input, [id]');
                return Array.from(els).slice(0, 30).map(e =>
                    e.tagName + (e.id ? '#'+e.id : '') +
                    (e.className ? '.'+String(e.className).split(' ')[0] : '') +
                    (e.href ? '[href='+e.href.substring(0,60)+']' : '') +
                    (e.type ? '[type='+e.type+']' : '')
                );
            }""")
            print(f"         Знайдені елементи: {tags}")
        except Exception as ex:
            print(f"         (не вдалось перелічити елементи: {ex})")
        return None


async def main():
    if len(sys.argv) < 3:
        print("Використання: python3 test_cabinet_auth.py /шлях/до/ключа.jks ВашПароль")
        sys.exit(1)

    kep_file = sys.argv[1]
    password = " ".join(sys.argv[2:])
    print(f"Файл: {kep_file}")
    print(f"Пароль: {'*' * len(password)} ({len(password)} символів)")

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(
            headless=True,
            args=["--no-sandbox", "--disable-setuid-sandbox"],
        )
        context = await browser.new_context(
            user_agent=UA,
            locale="uk-UA",
            viewport={"width": 1280, "height": 800},
            java_script_enabled=True,
        )
        page = await context.new_page()
        page.on("framenavigated", lambda f: print(f"  >> nav: {f.url[:120]}"))
        page.on("console", lambda m: None)  # мовчки ігнорувати console.log

        # ── 1. cabinet.court.gov.ua/login ────────────────────────────────
        print("\n[1] Відкриваю cabinet.court.gov.ua/login ...")
        await page.goto(
            "https://cabinet.court.gov.ua/login",
            wait_until="networkidle",
            timeout=30_000,
        )
        await asyncio.sleep(3)
        await snap(page, "1_cabinet_login")

        link = await wait_and_log(page, "УВІЙТИ link", "a[href*='redirect']", timeout=5_000)
        if link:
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(3)
        else:
            # Спробувати альтернативний селектор
            link2 = await wait_and_log(page, "УВІЙТИ button", "button, a.btn, .login-btn", timeout=3_000)
            if link2:
                await link2.click()
                await page.wait_for_load_state("networkidle", timeout=20_000)
                await asyncio.sleep(3)

        await snap(page, "1b_after_login_click")

        # ── 2. id.court.gov.ua → натиснути id.gov.ua ────────────────────
        print("\n[2] Шукаю кнопку id.gov.ua ...")
        btn = await wait_and_log(page, "AuthIdGov button", "#AuthIdGov-button", timeout=10_000)
        if btn:
            await btn.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(3)
        else:
            # Пробуємо будь-яку кнопку/посилання з текстом id.gov.ua
            btn2 = await page.query_selector("text=id.gov.ua")
            if btn2:
                print("  [OK] знайдено за текстом 'id.gov.ua'")
                await btn2.click()
                await page.wait_for_load_state("networkidle", timeout=20_000)
                await asyncio.sleep(3)

        # Прийняти cookies якщо є
        cookie_btn = await page.query_selector("#CybotCookiebotDialogBodyButtonAccept")
        if cookie_btn:
            print("  [OK] Закриваю cookie-банер")
            await cookie_btn.click()
            await asyncio.sleep(1)

        await snap(page, "2_id_gov_ua")

        # ── 3. Файловий носій ────────────────────────────────────────────
        print("\n[3] Шукаю 'Файловий носій' ...")
        fl = await wait_and_log(page, "Файловий носій", "a[href='/euid-auth-js']", timeout=10_000)
        if fl:
            await fl.click()
            await page.wait_for_load_state("networkidle", timeout=20_000)
            await asyncio.sleep(4)
        else:
            fl2 = await page.query_selector("text=Файловий носій")
            if fl2:
                print("  [OK] знайдено за текстом 'Файловий носій'")
                await fl2.click()
                await page.wait_for_load_state("networkidle", timeout=20_000)
                await asyncio.sleep(4)

        await snap(page, "3_euid_widget")

        # ── 4. Вибрати АЦСК ─────────────────────────────────────────────
        print(f"\n[4] Вибираю АЦСК: {PRIVAT_CA}")

        sel_el = await page.query_selector("select")
        if sel_el:
            print("  [OK] Знайдено native <select>")
            await page.select_option("select", label=PRIVAT_CA)
        else:
            # Пробуємо MUI / кастомний dropdown
            dropdown = await page.query_selector(
                "[role='button'][aria-haspopup='listbox'], "
                ".MuiSelect-root, [class*='SelectInput'], "
                "[class*='select__control'], [class*='dropdown']"
            )
            if dropdown:
                print("  [OK] Знайдено кастомний dropdown, кліккаю...")
                await dropdown.click()
                await asyncio.sleep(1.5)
                for opt in await page.query_selector_all(
                    "[role='option'], [class*='select__option'], li[class*='option'], li"
                ):
                    text = (await opt.inner_text()).strip()
                    if "ПРИВАТБАНК" in text.upper():
                        print(f"  [OK] Клікаю: '{text[:80]}'")
                        await opt.click()
                        break
                else:
                    print("  УВАГА: ПриватБанк не знайдено в списку options")
            else:
                print("  УВАГА: dropdown не знайдено взагалі")

        await asyncio.sleep(1)
        await snap(page, "4_ca_selected")

        # ── 5. Завантажити файл ──────────────────────────────────────────
        print(f"\n[5] Завантажую файл: {Path(kep_file).name}")
        # #PKeyFileInput захований CSS (за drag-drop зоною) — state="attached" замість "visible"
        try:
            file_input = await page.wait_for_selector(
                "#PKeyFileInput", state="attached", timeout=8_000
            )
            print("  [OK] #PKeyFileInput знайдено в DOM (прихований елемент)")
            await file_input.set_input_files(kep_file)
            print("  [OK] Файл передано input-у")
            await asyncio.sleep(5)   # JS-бібліотека читає і розбирає JKS
            await snap(page, "5_file_uploaded")
        except PWTimeout:
            print("  ПОМИЛКА: #PKeyFileInput не знайдено навіть як прихований!")
            await snap(page, "5_no_file_input")

        # ── 6. Ввести пароль ─────────────────────────────────────────────
        print(f"\n[6] Вводжу пароль ({len(password)} символів) ...")
        pwd_input = await wait_and_log(page, "#PKeyPassword", "#PKeyPassword", timeout=5_000)
        if pwd_input:
            await pwd_input.fill(password)
            await asyncio.sleep(0.5)
        else:
            print("  ПОМИЛКА: поле пароля не знайдено!")

        await snap(page, "6_password_entered")

        # ── 7. Натиснути Продовжити ──────────────────────────────────────
        print("\n[7] Натискаю 'Продовжити' ...")
        cont_btn = await wait_and_log(
            page,
            "Продовжити button",
            "#id-app-login-sign-form-file-key-sign-button",
            timeout=5_000,
        )
        if cont_btn:
            await cont_btn.click()
        else:
            # Спробуємо кнопку за текстом
            btn_text = await page.query_selector("text=Продовжити")
            if btn_text:
                print("  [OK] Знайдено за текстом 'Продовжити'")
                await btn_text.click()
            else:
                print("  ПОМИЛКА: кнопка Продовжити не знайдена!")

        # Чекати редирект до cabinet
        for i in range(10):
            await asyncio.sleep(3)
            url = page.url
            try:
                body_text = await page.inner_text("body")
                short = " | ".join(l.strip() for l in body_text.splitlines() if l.strip())[:200]
            except Exception:
                short = ""
            print(f"  [{(i+1)*3}с] URL: {url}")
            if short:
                print(f"        Текст: {short}")
            if "cabinet.court.gov.ua" in url and "login" not in url:
                print("  *** АВТОРИЗАЦІЯ УСПІШНА! ***")
                break

        await snap(page, "7_after_continue")
        await browser.close()

    print("\nГотово! Перевірте скриншоти в debug_output/auth_*.png")


asyncio.run(main())

"""
Authentication to cabinet.court.gov.ua via KEP file (id.gov.ua IIT EUSign widget).

Flow:
  cabinet.court.gov.ua/login
    → id.court.gov.ua/authorise
    → id.gov.ua  (click "Авторизуватись з id.gov.ua")
    → id.gov.ua/euid-auth-js  (click "Файловий носій")
    → upload .jks + password + click "Продовжити"
    → redirect back to cabinet.court.gov.ua with session cookies

Важливо: cabinet.court.gov.ua — React SPA, і частина сесії (OAuth-токени)
зберігається не в cookies, а в localStorage. Тому session — це не просто
список cookies, а {"cookies": [...], "local_storage": {...}}, і при
повторному використанні сесії в новому браузерному контексті треба
відновити ОБИДВІ частини (див. apply_session()).
"""

import asyncio
import json
import time
from pathlib import Path
from typing import Optional

from playwright.async_api import async_playwright, TimeoutError as PWTimeout

SESSION_FILE = Path("sessions/cabinet_cookies.json")
SESSION_FILE.parent.mkdir(exist_ok=True)

CABINET_URL   = "https://cabinet.court.gov.ua"
PRIVAT_CA     = 'КНЕДП АЦСК АТ КБ "ПРИВАТБАНК"'
SESSION_TTL   = 3600 * 4   # 4 hours — re-auth after this


# ── Public API ────────────────────────────────────────────────────────────────

async def get_session(kep_file: str, password: str, ca_name: str = PRIVAT_CA) -> dict:
    """
    Return valid session {"cookies": [...], "local_storage": {...}} for cabinet.court.gov.ua.
    Uses cached session if still fresh; otherwise re-authenticates.
    """
    cached = _load_session()
    if cached:
        return cached
    session = await authenticate(kep_file, password, ca_name)
    _save_session(session)
    return session


async def apply_session(context, session: dict):
    """
    Inject a previously captured session (cookies + localStorage) into a
    fresh browser context, BEFORE navigating to cabinet.court.gov.ua.
    localStorage can only be set once we're on the right origin, so we use
    an init script that runs before the page's own JS on every navigation.
    """
    cookies = session.get("cookies") or []
    if cookies:
        await context.add_cookies(cookies)

    local_storage = session.get("local_storage") or {}
    session_storage = session.get("session_storage") or {}
    if local_storage or session_storage:
        init_script = f"""
        (() => {{
            const ls = {json.dumps(local_storage)};
            for (const k in ls) {{ try {{ window.localStorage.setItem(k, ls[k]); }} catch (e) {{}} }}
            const ss = {json.dumps(session_storage)};
            for (const k in ss) {{ try {{ window.sessionStorage.setItem(k, ss[k]); }} catch (e) {{}} }}
        }})();
        """
        await context.add_init_script(init_script)


async def authenticate(kep_file: str, password: str, ca_name: str = PRIVAT_CA) -> dict:
    """
    Full authentication flow. Returns {"cookies": [...], "local_storage": {...}}.
    Raises RuntimeError on failure.
    """
    kep_path = Path(kep_file)
    if not kep_path.exists():
        raise FileNotFoundError(f"КЕП-файл не знайдено: {kep_file}")

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

        try:
            # ── Step 1: cabinet → id.court.gov.ua ───────────────────────
            print("[auth] Відкриваю cabinet.court.gov.ua ...")
            await page.goto(f"{CABINET_URL}/login", wait_until="domcontentloaded", timeout=30_000)
            await asyncio.sleep(2)
            link = await page.query_selector("a[href*='redirect']")
            if not link:
                raise RuntimeError("Кнопка УВІЙТИ не знайдена")
            await link.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(2)

            # ── Step 2: id.court.gov.ua → id.gov.ua ─────────────────────
            print("[auth] Переходжу на id.gov.ua ...")
            btn = await page.query_selector("#AuthIdGov-button")
            if not btn:
                raise RuntimeError("Кнопка 'Авторизуватись з id.gov.ua' не знайдена")
            await btn.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)

            # ── Step 3: Прийняти cookies ─────────────────────────────────
            accept = await page.query_selector("#CybotCookiebotDialogBodyButtonAccept")
            if accept:
                await accept.click()
                await asyncio.sleep(1)

            # ── Step 4: Файловий носій ───────────────────────────────────
            print("[auth] Вибираю 'Файловий носій' ...")
            file_link = await page.query_selector("a[href='/euid-auth-js']")
            if not file_link:
                raise RuntimeError("Посилання 'Файловий носій' не знайдено")
            await file_link.click()
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(3)

            # ── Step 5: Вибрати АЦСК (надавача ключа) ───────────────────
            print(f"[auth] Вибираю АЦСК: {ca_name}")
            await _select_ca(page, ca_name)
            await asyncio.sleep(1)

            # ── Step 6: Завантажити файл ключа ───────────────────────────
            print(f"[auth] Завантажую КЕП файл: {kep_path.name}")
            # #PKeyFileInput прихований CSS (за drag-drop зоною) — state="attached"
            try:
                file_input = await page.wait_for_selector(
                    "#PKeyFileInput", state="attached", timeout=8_000
                )
            except PWTimeout:
                raise RuntimeError("Поле для файлу #PKeyFileInput не знайдено в DOM")
            await file_input.set_input_files(str(kep_path))
            await asyncio.sleep(5)  # JS-бібліотека читає і розбирає JKS

            # ── Step 7: Ввести пароль ─────────────────────────────────────
            print("[auth] Вводжу пароль ...")
            await page.fill("#PKeyPassword", password)
            await asyncio.sleep(0.5)

            # ── Step 8: Натиснути "Продовжити" ───────────────────────────
            print("[auth] Натискаю 'Продовжити' ...")
            await page.click("#id-app-login-sign-form-file-key-sign-button")

            # ── Step 8b: Підтвердити дані (id.gov.ua показує "Перевірте дані") ──
            # Після підпису виникає сторінка з ПІБ/РНОКПП — треба ще раз натиснути.
            # Важливо: чекаємо саме появу тексту "Перевірте дані", а не кнопки
            # "Продовжити" — вона з тим самим текстом є і на попередній формі,
            # тож wait_for_selector міг би "знайти" стару кнопку одразу.
            confirmed = False
            for _ in range(10):  # до ~20с
                await asyncio.sleep(2)
                body = await page.inner_text("body")
                if "cabinet.court.gov.ua" in page.url and "login" not in page.url:
                    break  # вже редиректнуло без сторінки підтвердження
                if "Перевірте дані" in body or "Зверніть увагу" in body:
                    print("[auth] Сторінка підтвердження даних — натискаю Продовжити...")
                    confirm_btn = await page.query_selector("button:has-text('Продовжити')")
                    if not confirm_btn:
                        confirm_btn = await page.query_selector("a:has-text('Продовжити')")
                    if confirm_btn:
                        await confirm_btn.click()
                        confirmed = True
                    break
            if not confirmed:
                print("[auth] Сторінка підтвердження не з'явилась (або вже редиректнуло)")

            # Чекаємо на редирект назад до cabinet.court.gov.ua.
            # Важливо: спочатку прилітає проміжний /login?code=... (обмін
            # OAuth-коду), і лише через кілька секунд SPA сама редиректить
            # на "/" зі справжньою сесією. Якщо зняти cookies на /login?code=
            # сесія буде недійсна — тож чекаємо саме зникнення /login.
            try:
                await page.wait_for_url(
                    lambda url: "cabinet.court.gov.ua" in url and "/login" not in url,
                    timeout=30_000,
                )
            except PWTimeout:
                err = await _get_error_text(page)
                raise RuntimeError(f"Авторизація не завершилась. {err}")

            # Дочекатись поки SPA довантажить дані і остаточно виставить сесію
            # (JWT-токени зазвичай пишуться в localStorage вже після цього).
            await page.wait_for_load_state("networkidle", timeout=15_000)
            await asyncio.sleep(2)

            print(f"[auth] Авторизовано! URL: {page.url}")

            # ── Step 9: Зберегти cookies + localStorage/sessionStorage ──────
            cookies = await context.cookies()
            local_storage = json.loads(
                await page.evaluate("() => JSON.stringify(window.localStorage)")
            )
            session_storage = json.loads(
                await page.evaluate("() => JSON.stringify(window.sessionStorage)")
            )
            print(
                f"[auth] Отримано {len(cookies)} cookies, "
                f"{len(local_storage)} ключів localStorage, "
                f"{len(session_storage)} ключів sessionStorage"
            )
            return {
                "cookies": cookies,
                "local_storage": local_storage,
                "session_storage": session_storage,
            }

        finally:
            await browser.close()


# ── Helpers ───────────────────────────────────────────────────────────────────

async def _select_ca(page, ca_name: str):
    """Select the certificate authority from the dropdown."""
    # Try native <select> first (Material UI often wraps one)
    try:
        await page.select_option("select", label=ca_name, timeout=3_000)
        return
    except Exception:
        pass

    # Fallback: click the custom dropdown, then click the option
    dropdown = await page.query_selector(
        ".jss-select, [role='button'][aria-haspopup='listbox'], "
        ".MuiSelect-root, [class*='Select']"
    )
    if dropdown:
        await dropdown.click()
        await asyncio.sleep(1)

    # Click the matching option by text
    options = await page.query_selector_all("li, [role='option']")
    for opt in options:
        text = (await opt.inner_text()).strip()
        if ca_name.lower() in text.lower():
            await opt.click()
            return

    # Last resort: type into a search field if present
    search = await page.query_selector("input[type='search'], input[role='combobox']")
    if search:
        await search.fill(ca_name)
        await asyncio.sleep(1)
        option = await page.query_selector(f"text={ca_name}")
        if option:
            await option.click()


async def _get_error_text(page) -> str:
    """Try to read any error message on the page."""
    for sel in [".error", ".alert", "[class*='error']", "[class*='Error']"]:
        el = await page.query_selector(sel)
        if el:
            return (await el.inner_text()).strip()
    return ""


def _load_session() -> Optional[dict]:
    """Load cached session if it is still fresh."""
    if not SESSION_FILE.exists():
        return None
    try:
        data = json.loads(SESSION_FILE.read_text())
        if time.time() - data.get("saved_at", 0) > SESSION_TTL:
            print("[auth] Сесія застаріла, потрібна повторна авторизація")
            return None
        return {
            "cookies": data.get("cookies", []),
            "local_storage": data.get("local_storage", {}),
            "session_storage": data.get("session_storage", {}),
        }
    except Exception:
        return None


def _save_session(session: dict):
    SESSION_FILE.write_text(
        json.dumps(
            {
                "saved_at": time.time(),
                "cookies": session.get("cookies", []),
                "local_storage": session.get("local_storage", {}),
                "session_storage": session.get("session_storage", {}),
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    print(f"[auth] Сесію збережено: {SESSION_FILE}")


def clear_session():
    """Force re-authentication on next request."""
    if SESSION_FILE.exists():
        SESSION_FILE.unlink()

"""
Authentication to cabinet.court.gov.ua via KEP file (id.gov.ua IIT EUSign widget).

Flow:
  cabinet.court.gov.ua/login
    → id.court.gov.ua/authorise
    → id.gov.ua  (click "Авторизуватись з id.gov.ua")
    → id.gov.ua/euid-auth-js  (click "Файловий носій")
    → upload .jks + password + click "Продовжити"
    → redirect back to cabinet.court.gov.ua with session cookies
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

async def get_session(kep_file: str, password: str, ca_name: str = PRIVAT_CA) -> list:
    """
    Return valid session cookies for cabinet.court.gov.ua.
    Uses cached session if still fresh; otherwise re-authenticates.
    """
    cached = _load_session()
    if cached:
        return cached
    cookies = await authenticate(kep_file, password, ca_name)
    _save_session(cookies)
    return cookies


async def authenticate(kep_file: str, password: str, ca_name: str = PRIVAT_CA) -> list:
    """
    Full authentication flow. Returns list of cookie dicts.
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
            # Після підпису виникає сторінка з ПІБ/РНОКПП — треба ще раз натиснути
            try:
                await page.wait_for_selector(
                    "button:has-text('Продовжити'), a:has-text('Продовжити')",
                    timeout=15_000,
                )
                body = await page.inner_text("body")
                if "Перевірте дані" in body or "Зверніть увагу" in body:
                    print("[auth] Сторінка підтвердження даних — натискаю Продовжити...")
                    confirm_btn = await page.query_selector("button:has-text('Продовжити')")
                    if not confirm_btn:
                        confirm_btn = await page.query_selector("a:has-text('Продовжити')")
                    if confirm_btn:
                        await confirm_btn.click()
            except PWTimeout:
                pass  # сторінка підтвердження не з'явилась — це теж нормально

            # Чекаємо на редирект назад до cabinet.court.gov.ua
            try:
                await page.wait_for_url(f"{CABINET_URL}/**", timeout=30_000)
            except PWTimeout:
                err = await _get_error_text(page)
                raise RuntimeError(f"Авторизація не завершилась. {err}")

            print(f"[auth] Авторизовано! URL: {page.url}")

            # ── Step 9: Зберегти cookies ──────────────────────────────────
            cookies = await context.cookies()
            print(f"[auth] Отримано {len(cookies)} cookies")
            return cookies

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


def _load_session() -> Optional[list]:
    """Load cached session cookies if they are still fresh."""
    if not SESSION_FILE.exists():
        return None
    try:
        data = json.loads(SESSION_FILE.read_text())
        if time.time() - data.get("saved_at", 0) > SESSION_TTL:
            print("[auth] Сесія застаріла, потрібна повторна авторизація")
            return None
        return data["cookies"]
    except Exception:
        return None


def _save_session(cookies: list):
    SESSION_FILE.write_text(
        json.dumps({"saved_at": time.time(), "cookies": cookies}, ensure_ascii=False, indent=2)
    )
    print(f"[auth] Сесію збережено: {SESSION_FILE}")


def clear_session():
    """Force re-authentication on next request."""
    if SESSION_FILE.exists():
        SESSION_FILE.unlink()

"""
Scraper for cabinet.court.gov.ua — personal court cases.
Requires authenticated session cookies from cabinet_auth.py.
"""

import asyncio
from typing import List

from playwright.async_api import async_playwright

from app.models import CourtCase, SearchResult

CABINET_URL  = "https://cabinet.court.gov.ua"
CASES_PATH   = "/cases"       # adjust after inspecting the logged-in page


async def get_my_cases(cookies: list) -> SearchResult:
    """
    Fetch personal court cases from cabinet.court.gov.ua.
    `cookies` — list returned by cabinet_auth.authenticate()
    """
    cases: List[CourtCase] = []

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
        # Inject saved cookies so we are authenticated
        await context.add_cookies(cookies)

        page = await context.new_page()

        print(f"[cabinet] Відкриваю {CABINET_URL}{CASES_PATH} ...")
        await page.goto(f"{CABINET_URL}{CASES_PATH}", wait_until="networkidle", timeout=30_000)
        await asyncio.sleep(2)

        # Debug: save screenshot of the cases page
        await page.screenshot(path="debug_output/cabinet_cases.png", full_page=True)

        # Parse cases (selectors will be updated after seeing the real page)
        cases = await _parse_cases(page)

        await browser.close()

    return SearchResult(query="cabinet", total_found=len(cases), cases=cases)


async def _parse_cases(page) -> List[CourtCase]:
    """Parse the list of personal cases. Selectors TBD after first login."""
    cases = []

    # Try common table/list patterns
    rows = await page.query_selector_all("tr.case-row, tr.odd, tr.even, .case-item, li.case")
    if not rows:
        # Fallback — try any table rows with links
        rows = await page.query_selector_all("tbody tr")

    for row in rows:
        try:
            link_el = await row.query_selector("a[href*='case'], a[href*='Case']")
            if not link_el:
                continue

            href = await link_el.get_attribute("href") or ""
            url  = href if href.startswith("http") else f"{CABINET_URL}{href}"

            tds = await row.query_selector_all("td")
            case_number = (await tds[0].inner_text()).strip() if len(tds) > 0 else "—"
            court_name  = (await tds[1].inner_text()).strip() if len(tds) > 1 else "—"
            date        = (await tds[2].inner_text()).strip() if len(tds) > 2 else "—"
            doc_type    = (await tds[3].inner_text()).strip() if len(tds) > 3 else "—"

            cases.append(CourtCase(
                case_number=case_number,
                court_name=court_name,
                date=date,
                document_type=doc_type,
                url=url,
            ))
        except Exception as e:
            print(f"[cabinet] Помилка парсингу рядка: {e}")

    print(f"[cabinet] Знайдено {len(cases)} справ")
    return cases

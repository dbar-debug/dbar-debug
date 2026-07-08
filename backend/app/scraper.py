"""
Scraper for the Ukrainian court registry (reyestr.court.gov.ua).

Uses Playwright to handle the JavaScript-heavy site.
Install: pip install playwright && playwright install chromium
"""

import asyncio
import re
from typing import List

from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeout

from app.models import CourtCase, SearchResult

REGISTRY_URL = "https://reyestr.court.gov.ua"
SEARCH_INPUT_SELECTOR = "#SearchExpression"
SUBMIT_BUTTON_SELECTOR = "#btn"
# Result row selectors — confirmed from site inspection
RESULT_ITEM_SELECTOR = "tr.odd, tr.even"


async def search_by_name(full_name: str, max_pages: int = 3) -> SearchResult:
    """
    Search Ukrainian court registry by person full name.

    Args:
        full_name: Person's full name in Ukrainian, e.g. "Іваненко Іван Іванович"
        max_pages: How many result pages to fetch (each page ~10 results)

    Returns:
        SearchResult with list of CourtCase objects
    """
    cases: List[CourtCase] = []
    total_found = 0

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
            print(f"[scraper] Opening {REGISTRY_URL} ...")
            await page.goto(REGISTRY_URL, wait_until="networkidle", timeout=30_000)

            # Fill search field and click submit button
            await page.wait_for_selector(SEARCH_INPUT_SELECTOR, timeout=10_000)
            await page.fill(SEARCH_INPUT_SELECTOR, full_name)
            await page.click(SUBMIT_BUTTON_SELECTOR)
            await page.wait_for_load_state("networkidle", timeout=15_000)

            # Total count shown near top of results
            total_text = await page.text_content(".searchResultText, .pagerRecords, #pagerRecords")
            if total_text:
                numbers = re.findall(r"\d+", total_text)
                if numbers:
                    total_found = int(numbers[0])

            for page_num in range(max_pages):
                print(f"[scraper] Parsing page {page_num + 1} ...")
                page_cases = await _parse_results_page(page)
                cases.extend(page_cases)

                if not page_cases:
                    break

                # Try to click "next page"
                next_btn = page.locator("a.pagerNext, a[title*='наступ'], a[title*='Наступ']")
                if await next_btn.count() == 0:
                    break
                await next_btn.click()
                await page.wait_for_load_state("networkidle", timeout=15_000)

        except PlaywrightTimeout as e:
            print(f"[scraper] Timeout: {e}")
        except Exception as e:
            print(f"[scraper] Error: {e}")
            raise
        finally:
            await browser.close()

    return SearchResult(query=full_name, total_found=total_found or len(cases), cases=cases)


async def _parse_results_page(page) -> List[CourtCase]:
    """Extract CourtCase objects from the current results page."""
    cases = []
    items = await page.query_selector_all(RESULT_ITEM_SELECTOR)
    for item in items:
        try:
            case = await _extract_case(item)
            if case:
                cases.append(case)
        except Exception as e:
            print(f"[scraper] Skipping item due to error: {e}")
    return cases


async def _extract_case(item) -> CourtCase | None:
    """
    Extract fields from a single <tr class='odd'|'even'> row.

    reyestr.court.gov.ua table column order (confirmed from HTML):
      td[0] — document type / title  (contains <a href='/Review/...'>)
      td[1] — court name
      td[2] — case number
      td[3] — date (registration)
    """
    def _text(val: str | None) -> str:
        return val.strip() if val else "—"

    tds = await item.query_selector_all("td")
    if len(tds) < 2:
        return None

    # Column 0 — link + document type
    link_el = await tds[0].query_selector("a[href*='/Review/']")
    url = ""
    doc_type = ""
    if link_el:
        href = await link_el.get_attribute("href") or ""
        url = href if href.startswith("http") else f"https://reyestr.court.gov.ua{href}"
        doc_type = _text(await link_el.inner_text())

    court_name  = _text(await tds[1].inner_text()) if len(tds) > 1 else "—"
    case_number = _text(await tds[2].inner_text()) if len(tds) > 2 else "—"
    date        = _text(await tds[3].inner_text()) if len(tds) > 3 else "—"

    if not url and case_number == "—":
        return None

    return CourtCase(
        case_number=case_number,
        court_name=court_name,
        date=date,
        document_type=doc_type,
        url=url,
    )


async def _inner_text(parent, selector: str) -> str | None:
    """Return inner text of first matching child, or None."""
    el = await parent.query_selector(selector)
    if el:
        return await el.inner_text()
    return None


# Quick manual test
if __name__ == "__main__":
    import sys

    name = sys.argv[1] if len(sys.argv) > 1 else "Іваненко Іван Іванович"
    result = asyncio.run(search_by_name(name, max_pages=1))

    print(f"\nЗнайдено: {result.total_found} документів для '{result.query}'")
    print("-" * 60)
    for c in result.cases:
        print(f"№ {c.case_number}  |  {c.date}  |  {c.court_name}")
        print(f"  Тип: {c.document_type}")
        print(f"  URL: {c.url}")
        if c.excerpt:
            print(f"  Уривок: {c.excerpt[:120]}...")
        print()

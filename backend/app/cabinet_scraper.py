"""
Fetches personal court cases from cabinet.court.gov.ua via its internal
JSON API (discovered by capturing the SPA's own XHR calls — see
debug_cabinet_cases.py). No HTML scraping needed: cabinet.court.gov.ua
is a React app, and "Мої справи" loads from GET /api/cases/my.

Requires an authenticated session from cabinet_auth.py.
"""

from typing import List

from playwright.async_api import async_playwright

from app.models import CourtCase, SearchResult

CABINET_URL = "https://cabinet.court.gov.ua"


async def get_my_cases(session: dict) -> SearchResult:
    """
    Fetch personal court cases from cabinet.court.gov.ua's internal API.
    `session` — dict returned by cabinet_auth.get_session()/authenticate(),
    i.e. {"cookies": [...], "local_storage": {...}, "session_storage": {...}}
    """
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    async with async_playwright() as pw:
        # Лише HTTP-запити — не потрібен headless Chromium, лише cookies
        # + Bearer token, які вже отримані під час КЕП-автентифікації.
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )

        try:
            my_user_id = await _get_my_user_id(api)
            courts = await _get_dictionary(api, "/api/dictionaries/courts", key="name")
            roles = await _get_dictionary(api, "/api/dictionaries/cases/member_roles", key="description")
            raw_cases = await _get_my_cases_raw(api)
        finally:
            await api.dispose()

    cases = [_to_court_case(rc, my_user_id, courts, roles) for rc in raw_cases]
    print(f"[cabinet] Знайдено {len(cases)} справ")

    return SearchResult(query="cabinet", total_found=len(cases), cases=cases)


async def _get_my_user_id(api) -> str:
    resp = await api.get(f"{CABINET_URL}/api/auth/me")
    data = (await resp.json())["data"]
    return data["userId"]


async def _get_dictionary(api, path: str, key: str) -> dict:
    resp = await api.get(f"{CABINET_URL}{path}")
    items = (await resp.json())["data"]
    return {item["id"]: item[key] for item in items}


async def _get_my_cases_raw(api) -> List[dict]:
    all_cases: List[dict] = []
    start = 0
    page_size = 200
    while True:
        resp = await api.get(
            f"{CABINET_URL}/api/cases/my",
            params={"start": start, "count": page_size, "is_not_deleted": 1},
        )
        page = (await resp.json())["data"]
        all_cases.extend(page)
        if len(page) < page_size:
            break
        start += page_size
    return all_cases


def _to_court_case(raw: dict, my_user_id: str, courts: dict, roles: dict) -> CourtCase:
    my_member = next(
        (m for m in raw.get("caseMembers", []) if m.get("userId") == my_user_id),
        None,
    )
    my_role = roles.get(my_member["roleId"], "—") if my_member else "—"

    date = raw.get("docDateLast") or raw.get("docDateFirst") or ""
    date = date[:10] if date else "—"  # YYYY-MM-DD

    return CourtCase(
        case_number=raw.get("number", "—"),
        court_name=courts.get(raw.get("courtId"), "—"),
        date=date,
        document_type=my_role,
        url=f"{CABINET_URL}/cases/{raw.get('id', '')}",
    )

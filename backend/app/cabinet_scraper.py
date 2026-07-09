"""
Fetches personal court cases from cabinet.court.gov.ua via its internal
JSON API (discovered by capturing the SPA's own XHR calls — see
debug_cabinet_cases.py). No HTML scraping needed: cabinet.court.gov.ua
is a React app, and "Мої справи" loads from GET /api/cases/my.

That one response already embeds caseMembers (all parties, not just the
caller) and caseJudges (full panel), so we extract everything from it —
no extra requests needed for those two lists.

Requires an authenticated session from cabinet_auth.py.
"""

from typing import List

from playwright.async_api import async_playwright

from app.models import CaseDocument, CaseJudge, CaseMember, CourtCase, SearchResult

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
            member_roles = await _get_dictionary(api, "/api/dictionaries/cases/member_roles", key="description")
            judge_roles = await _get_dictionary(api, "/api/dictionaries/cases/judge_roles", key="description")
            statuses = await _get_dictionary(api, "/api/dictionaries/case_statuses", key="name")
            raw_cases = await _get_my_cases_raw(api)
        finally:
            await api.dispose()

    cases = [
        _to_court_case(rc, my_user_id, courts, member_roles, judge_roles, statuses)
        for rc in raw_cases
    ]
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


def _to_court_case(
    raw: dict,
    my_user_id: str,
    courts: dict,
    member_roles: dict,
    judge_roles: dict,
    statuses: dict,
) -> CourtCase:
    members = _extract_members(raw, member_roles)
    judges = _extract_judges(raw, judge_roles)

    my_member = next(
        (m for m in raw.get("caseMembers", []) if m.get("userId") == my_user_id),
        None,
    )
    my_role = member_roles.get(my_member["roleId"], "—") if my_member else "—"

    date = raw.get("docDateLast") or raw.get("docDateFirst") or ""
    date = date[:10] if date else "—"  # YYYY-MM-DD

    presiding = [j.name for j in judges if j.role == "Головуючий"]
    judge_summary = ", ".join(dict.fromkeys(presiding)) if presiding else (
        ", ".join(dict.fromkeys(j.name for j in judges)) or "—"
    )

    # Номер провадження (procNumber) лежить у caseJudges, напр. "2/754/9750/26"
    proc_numbers = [
        j.get("procNumber", "")
        for j in raw.get("caseJudges") or []
        if j.get("procNumber")
    ]
    proceeding_number = ", ".join(dict.fromkeys(proc_numbers)) if proc_numbers else ""

    return CourtCase(
        case_number=raw.get("number", "—"),
        court_name=courts.get(raw.get("courtId"), "—"),
        date=date,
        document_type=my_role,
        url=f"{CABINET_URL}/cases/{raw.get('id', '')}",
        status=statuses.get(raw.get("status"), "—"),
        judge=judge_summary,
        created_at=(raw.get("createdAt") or "")[:10],
        updated_at=(raw.get("updatedAt") or "")[:10],
        proceeding_number=proceeding_number,
        case_id=raw.get("id", ""),
        members=members,
        judges=judges,
    )


async def get_case_documents(session: dict, case_id: str) -> List[CaseDocument]:
    """
    Повертає документи по справі через /api/documents/case.
    Показує рух справи: рішення, ухвали, реєстраційні картки,
    'Внесення дат слухання' тощо — відсортовані від новіших до старіших.
    """
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    documents: List[CaseDocument] = []
    async with async_playwright() as pw:
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )
        try:
            start = 0
            page_size = 100
            while True:
                resp = await api.get(
                    f"{CABINET_URL}/api/documents/case",
                    params={
                        "case_id": case_id,
                        "start": start,
                        "count": page_size,
                        "sort[docDate]": "desc",
                        "is_not_deleted": 1,
                    },
                )
                page = (await resp.json()).get("data") or []
                for d in page:
                    documents.append(
                        CaseDocument(
                            number=d.get("number", "—"),
                            date=(d.get("docDate") or "")[:10],
                            description=d.get("description", "—"),
                            doc_id=d.get("id", ""),
                        )
                    )
                if len(page) < page_size:
                    break
                start += page_size
        finally:
            await api.dispose()

    print(f"[cabinet] Справа {case_id}: знайдено {len(documents)} документів")
    return documents


def _extract_members(raw: dict, member_roles: dict) -> List[CaseMember]:
    seen = set()
    members: List[CaseMember] = []
    for m in raw.get("caseMembers") or []:
        name = m.get("name") or m.get("companyName") or "—"
        role = member_roles.get(m.get("roleId"), "—")
        key = (name, role)
        if key in seen:
            continue
        seen.add(key)
        members.append(CaseMember(name=name, role=role))
    return members


def _extract_judges(raw: dict, judge_roles: dict) -> List[CaseJudge]:
    seen = set()
    judges: List[CaseJudge] = []
    for j in raw.get("caseJudges") or []:
        name = j.get("name") or "—"
        role = judge_roles.get(j.get("roleId"), "—")
        key = (name, role)
        if key in seen or name == "—":
            continue
        seen.add(key)
        judges.append(CaseJudge(name=name, role=role))
    return judges

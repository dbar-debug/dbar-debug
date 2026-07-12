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


async def get_calendar_events(session: dict) -> List[dict]:
    """
    Збирає всі документи всіх справ як події для календаря (за один сеанс).
    Кожна подія: {date, case_number, court_name, description, doc_id, case_id}.
    Документи типу 'Внесення дат слухання' позначають призначені засідання.
    """
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    events: List[dict] = []
    async with async_playwright() as pw:
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )
        try:
            courts = await _get_dictionary(api, "/api/dictionaries/courts", key="name")
            raw_cases = await _get_my_cases_raw(api)
            for case in raw_cases:
                case_id = case.get("id", "")
                case_number = case.get("number", "—")
                court_name = courts.get(case.get("courtId"), "—")

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
                        date = (d.get("docDate") or "")[:10]
                        if not date:
                            continue
                        events.append({
                            "date": date,
                            "case_number": case_number,
                            "court_name": court_name,
                            "description": d.get("description", "—"),
                            "doc_id": d.get("id", ""),
                            "case_id": case_id,
                        })
                    if len(page) < page_size:
                        break
                    start += page_size
        finally:
            await api.dispose()

    print(f"[cabinet] Календар: {len(events)} подій з {len(raw_cases)} справ")
    return events


async def get_cabinet_hearings(session: dict) -> List[dict]:
    """
    Судові засідання з руху справ у кабінеті. Документи типу
    'Внесення дат слухання' мають у полі docDate реальну дату й час
    засідання (місцевий київський час, попри суфікс 'Z'). Це головне
    джерело МИНУЛИХ засідань, яких немає у відкритому наборі даних.

    Кожне засідання збагачуємо судом/суддями/сторонами зі справи, щоб
    формат збігався з засіданнями з відкритих даних (Hearing).
    """
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    hearings: List[dict] = []
    async with async_playwright() as pw:
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )
        try:
            courts = await _get_dictionary(api, "/api/dictionaries/courts", key="name")
            member_roles = await _get_dictionary(api, "/api/dictionaries/cases/member_roles", key="description")
            judge_roles = await _get_dictionary(api, "/api/dictionaries/cases/judge_roles", key="description")
            raw_cases = await _get_my_cases_raw(api)

            for case in raw_cases:
                case_id = case.get("id", "")
                case_number = case.get("number", "—")
                court_name = courts.get(case.get("courtId"), "—")
                involved = _members_summary(case, member_roles)
                judges = _judges_summary(case, judge_roles)

                seen = set()
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
                        if (d.get("description") or "") != "Внесення дат слухання":
                            continue
                        doc_date = d.get("docDate") or ""
                        if len(doc_date) < 10:
                            continue
                        date_iso = doc_date[:10]                 # YYYY-MM-DD
                        htime = doc_date[11:16] if len(doc_date) >= 16 else ""  # HH:MM (місцевий)
                        dedup = (date_iso, htime)
                        if dedup in seen:
                            continue
                        seen.add(dedup)
                        hearings.append({
                            "date": date_iso,
                            "time": htime,
                            "case_number": case_number,
                            "court_name": court_name,
                            "judges": judges,
                            "case_involved": involved,
                            "case_description": "",
                            "court_room": "",
                        })
                    if len(page) < page_size:
                        break
                    start += page_size
        finally:
            await api.dispose()

    print(f"[cabinet] Засідань з руху справ: {len(hearings)}")
    return hearings


def _members_summary(raw: dict, member_roles: dict) -> str:
    """'Позивач: X, Відповідач: Y' зі складу учасників справи."""
    parts = []
    seen = set()
    for m in raw.get("caseMembers") or []:
        name = m.get("name") or m.get("companyName") or ""
        role = member_roles.get(m.get("roleId"), "")
        if not name:
            continue
        key = (role, name)
        if key in seen:
            continue
        seen.add(key)
        parts.append(f"{role}: {name}" if role else name)
    return ", ".join(parts)


def _judges_summary(raw: dict, judge_roles: dict) -> str:
    """'Головуючий суддя: X' зі складу суду."""
    names = []
    seen = set()
    for j in raw.get("caseJudges") or []:
        name = j.get("name") or ""
        if not name or name in seen:
            continue
        seen.add(name)
        names.append(name)
    if not names:
        return ""
    return "Головуючий суддя: " + ", ".join(names)


async def get_document_file(session: dict, doc_id: str) -> tuple[bytes, str]:
    """
    Повертає (вміст_файлу, content_type) документа через
    /api/documents/{doc_id}/scan_file. Файл може бути HTML (текст
    рішення) або PDF — content_type беремо з відповіді суду.
    """
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    async with async_playwright() as pw:
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )
        try:
            resp = await api.get(f"{CABINET_URL}/api/documents/{doc_id}/scan_file")
            body = await resp.body()
            content_type = resp.headers.get("content-type", "application/octet-stream")
        finally:
            await api.dispose()

    print(f"[cabinet] Документ {doc_id}: {len(body)} байт, {content_type}")
    return body, content_type


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

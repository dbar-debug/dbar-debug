import asyncio
import os
import urllib.request

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.scraper import search_by_name
from app.cabinet_auth import get_session, clear_session
from app.cabinet_scraper import get_my_cases, get_case_documents, get_document_file, get_calendar_events, get_cabinet_hearings
from app.hearings import get_hearings_for_cases, get_hearings_for_name
from app.status import get_status_for_name
from app import decisions_db
from app import debtors_db
from app.models import SearchResult

CABINET_URL = "https://cabinet.court.gov.ua"

app = FastAPI(
    title="Court Cases API",
    description="Пошук судових справ в реєстрі України",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Обмежити після запуску Flutter-додатку
    allow_methods=["GET"],
    allow_headers=["*"],
)


class LoginRequest(BaseModel):
    kep_file: str   # абсолютний шлях до .jks файлу на сервері
    password: str
    ca_name: str = 'КНЕДП АЦСК АТ КБ "ПРИВАТБАНК"'


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.post("/cabinet/login")
async def cabinet_login(req: LoginRequest):
    """Авторизація через КЕП. Зберігає сесію на сервері."""
    try:
        clear_session()  # примусова свіжа авторизація
        session = await get_session(req.kep_file, req.password, req.ca_name)
        return {"status": "ok", "cookies_count": len(session["cookies"])}
    except FileNotFoundError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=401, detail=str(e))


@app.get("/cabinet/cases")
async def cabinet_cases():
    """Повертає особисті судові справи з cabinet.court.gov.ua."""
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise HTTPException(
            status_code=400,
            detail="Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env файлі або викличте /cabinet/login"
        )
    try:
        session = await get_session(kep_file, password)
        result  = await get_my_cases(session)
        return {
            "total_found": result.total_found,
            "cases": [
                {
                    "case_number": c.case_number,
                    "court_name":  c.court_name,
                    "date":        c.date,
                    "my_role":     c.document_type,
                    "status":      c.status,
                    "judge":       c.judge,
                    "url":         c.url,
                    "created_at":  c.created_at,
                    "updated_at":  c.updated_at,
                    "proceeding_number": c.proceeding_number,
                    "case_id":     c.case_id,
                    "members": [
                        {"name": m.name, "role": m.role} for m in c.members
                    ],
                    "judges": [
                        {"name": j.name, "role": j.role} for j in c.judges
                    ],
                }
                for c in result.cases
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/cabinet/cases/{case_id}/documents")
async def cabinet_case_documents(case_id: str):
    """Повертає документи по конкретній справі (рух справи, ухвали, рішення)."""
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise HTTPException(
            status_code=400,
            detail="Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env файлі або викличте /cabinet/login"
        )
    try:
        session = await get_session(kep_file, password)
        docs = await get_case_documents(session, case_id)
        return {
            "total_found": len(docs),
            "documents": [
                {
                    "number":      d.number,
                    "date":        d.date,
                    "description": d.description,
                    "doc_id":      d.doc_id,
                }
                for d in docs
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/cabinet/hearings")
async def cabinet_hearings():
    """
    Майбутні судові засідання по справах користувача — з відкритих даних
    'Список справ призначених до розгляду' (data.gov.ua), зіставлені за
    номерами справ з кабінету.
    """
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise HTTPException(status_code=400, detail="Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env")
    try:
        session = await get_session(kep_file, password)
        result = await get_my_cases(session)
        numbers = [c.case_number for c in result.cases if c.case_number and c.case_number != "—"]

        # Майбутні — з відкритих даних (є зал/суть спору); минулі та всі
        # інші — з руху справ у кабінеті. Зливаємо, надаючи перевагу
        # запису з відкритих даних (він багатший) при збігу.
        future = await get_hearings_for_cases(numbers)
        past = await get_cabinet_hearings(session)
        hearings = _merge_hearings(future, past)
        return {"total_found": len(hearings), "hearings": hearings}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _merge_hearings(preferred: list[dict], other: list[dict]) -> list[dict]:
    """Зливає два списки засідань, дедуплікуючи за (справа, дата, час).
    При збігу лишається запис з `preferred` (детальніший)."""
    by_key: dict = {}
    for h in other:
        by_key[(h["case_number"], h["date"], h["time"])] = h
    for h in preferred:
        by_key[(h["case_number"], h["date"], h["time"])] = h
    merged = list(by_key.values())
    merged.sort(key=lambda h: (h["date"], h["time"]))
    return merged


@app.get("/hearings/by-name")
async def hearings_by_name(
    name: str = Query(..., description="ПІБ особи", example="Барцуков Денис Станіславович"),
):
    """
    Публічний пошук судових засідань за ПІБ у відкритих даних
    'Список справ призначених до розгляду'. Без КЕП — для будь-якого
    користувача. Повертає засідання, де імʼя фігурує серед учасників.
    """
    if len(name.strip()) < 5:
        raise HTTPException(status_code=400, detail="Введіть повне ПІБ (мінімум 5 символів)")
    hearings = await get_hearings_for_name(name.strip())
    return {"total_found": len(hearings), "hearings": hearings}


@app.get("/status/by-name")
async def status_by_name(
    name: str = Query(..., description="ПІБ особи", example="Барцуков Денис Станіславович"),
):
    """
    Публічний пошук СТАНУ розгляду справ за ПІБ у відкритих даних
    'Інформація щодо стану розгляду справ'. Повертає справи, де імʼя
    фігурує серед сторін, з поточною стадією та результатом.
    """
    if len(name.strip()) < 5:
        raise HTTPException(status_code=400, detail="Введіть повне ПІБ (мінімум 5 символів)")
    cases = await get_status_for_name(name.strip())
    return {"total_found": len(cases), "cases": cases}


@app.get("/person/cases")
async def person_cases(
    name: str = Query(..., description="ПІБ особи", example="Барцуков Денис Станіславович"),
):
    """
    Обʼєднаний перелік справ людини за ПІБ: зливає СТАН справ (поточна
    стадія) і ЗАСІДАННЯ (розклад) за номером справи. Рішення підтягуються
    окремо (/decisions/by-case) на вимогу. Без КЕП.
    """
    if len(name.strip()) < 5:
        raise HTTPException(status_code=400, detail="Введіть повне ПІБ (мінімум 5 символів)")

    status_cases = await get_status_for_name(name.strip())
    hearings = await get_hearings_for_name(name.strip())

    # Зводимо все за номером справи
    cases: dict = {}

    def _slot(num: str) -> dict:
        return cases.setdefault(num, {
            "case_number": num,
            "court_name": "",
            "judge": "",
            "participants": "",
            "description": "",
            "stage_name": "",
            "stage_date": "",
            "hearings": [],
            "next_hearing": None,
        })

    for c in status_cases:
        num = c.get("case_number") or ""
        if not num:
            continue
        s = _slot(num)
        s["court_name"] = c.get("court_name") or s["court_name"]
        s["judge"] = c.get("judge") or s["judge"]
        s["participants"] = c.get("participants") or s["participants"]
        s["description"] = c.get("description") or s["description"]
        s["stage_name"] = c.get("stage_name") or ""
        s["stage_date"] = c.get("stage_date") or ""

    for h in hearings:
        num = h.get("case_number") or ""
        if not num:
            continue
        s = _slot(num)
        s["court_name"] = s["court_name"] or (h.get("court_name") or "")
        s["judge"] = s["judge"] or (h.get("judges") or "")
        s["participants"] = s["participants"] or (h.get("case_involved") or "")
        s["description"] = s["description"] or (h.get("case_description") or "")
        s["hearings"].append({
            "date": h.get("date") or "",
            "time": h.get("time") or "",
            "court_room": h.get("court_room") or "",
        })

    # Найближче майбутнє засідання по кожній справі
    import datetime
    today = datetime.date.today().isoformat()
    for s in cases.values():
        s["hearings"].sort(key=lambda x: (x["date"], x["time"]))
        future = [h for h in s["hearings"] if h["date"] >= today]
        s["next_hearing"] = future[0] if future else None

    # Сортуємо справи: спершу з майбутнім засіданням (найближче), потім за стадією
    def _sort_key(s):
        nh = s["next_hearing"]["date"] if s["next_hearing"] else "9999"
        return (nh, )

    result = sorted(cases.values(), key=_sort_key)
    return {"total_found": len(result), "cases": result}


@app.get("/debtors/search")
async def debtors_search(
    q: str = Query(..., description="ПІБ або код (ІПН/ЄДРПОУ)", example="Барцуков Денис"),
):
    """
    Пошук у Єдиному реєстрі боржників за ПІБ або кодом (ІПН/ЄДРПОУ).
    Якщо запит складається лише з цифр — шукаємо за кодом, інакше за ПІБ.
    """
    query = q.strip()
    if len(query) < 4:
        raise HTTPException(status_code=400, detail="Введіть ПІБ (мін. 4 символи) або код")
    if not debtors_db.available():
        return {"total_found": 0, "debtors": []}

    digits = query.replace(" ", "")
    if digits.isdigit():
        rows = await asyncio.to_thread(debtors_db.query_by_code, digits)
    else:
        name_norm = " ".join(query.lower().split())
        rows = await asyncio.to_thread(debtors_db.query_by_name, name_norm)
    return {"total_found": len(rows), "debtors": rows}


@app.get("/decisions/by-case")
async def decisions_by_case(
    number: str = Query(..., description="Номер справи", example="754/899/26"),
):
    """
    Рішення ЄДРСР за номером справи (текст — за посиланням text_url).
    Публічний, без КЕП.
    """
    import asyncio
    if not number.strip():
        raise HTTPException(status_code=400, detail="Вкажіть номер справи")
    if not decisions_db.available():
        return {"total_found": 0, "decisions": []}
    decisions = await asyncio.to_thread(decisions_db.query_by_case, number.strip())
    return {"total_found": len(decisions), "decisions": decisions}


def _fetch_bytes(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (court-app)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


@app.get("/decisions/{doc_id}/file")
async def decision_file(doc_id: str, download: int = 0):
    """
    Проксіює текст рішення ЄДРСР: качає .rtf і віддає як читабельний HTML
    зі свого домену (щоб відкривалось усередині додатку, без блокування
    iframe). download=1 — віддає оригінальний .rtf для збереження.
    """
    if not decisions_db.available():
        raise HTTPException(status_code=404, detail="Індекс рішень недоступний")
    rec = await asyncio.to_thread(decisions_db.get_by_doc_id, doc_id)
    if not rec or not rec.get("doc_url"):
        raise HTTPException(status_code=404, detail="Текст рішення недоступний")

    try:
        body = await asyncio.to_thread(_fetch_bytes, rec["doc_url"])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Не вдалося завантажити рішення: {e}")

    if download:
        headers = {"Content-Disposition": f'attachment; filename="decision-{doc_id}.rtf"'}
        return Response(content=body, media_type="application/rtf", headers=headers)

    from app.rtf import rtf_to_html
    title = f'{rec.get("judgment_form", "Рішення")} у справі {rec.get("cause_num", "")}'.strip()
    html = await asyncio.to_thread(rtf_to_html, body, title)
    return Response(content=html.encode("utf-8"), media_type="text/html; charset=utf-8")


@app.get("/cabinet/calendar")
async def cabinet_calendar():
    """Повертає всі події (документи всіх справ) для календаря."""
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise HTTPException(status_code=400, detail="Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env")
    try:
        session = await get_session(kep_file, password)
        events = await get_calendar_events(session)
        return {"total_found": len(events), "events": events}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/cabinet/documents/{doc_id}/file")
async def cabinet_document_file(doc_id: str, download: int = 0):
    """
    Проксіює файл документа з cabinet.court.gov.ua (рішення/ухвала —
    HTML або PDF). Авторизація (Bearer/cookies) додається на сервері,
    тож клієнт може відкрити цей URL напряму без облікових даних.

    download=1 → віддаємо із Content-Disposition: attachment, щоб браузер
    зберіг файл, а не показував його інлайн.
    """
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise HTTPException(status_code=400, detail="Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env")
    try:
        session = await get_session(kep_file, password)
        body, content_type = await get_document_file(session, doc_id)

        if "html" in content_type.lower():
            body, content_type = _prepare_html_document(body)

        headers = {}
        if download:
            ext = "pdf" if "pdf" in content_type.lower() else "html"
            headers["Content-Disposition"] = f'attachment; filename="document-{doc_id}.{ext}"'

        return Response(content=body, media_type=content_type, headers=headers)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


def _prepare_html_document(body: bytes) -> tuple[bytes, str]:
    """
    Судові HTML-рішення зазвичай у windows-1251. Визначаємо кодування,
    перекодовуємо у UTF-8, чистимо старий charset у <meta> і додаємо
    <base href> — щоб герб/стилі суду вантажились, а кирилиця не була
    ромбиками.
    """
    import re

    # 1. Визначаємо кодування
    head = body[:2048].decode("ascii", errors="ignore").lower()
    if "charset=windows-1251" in head or "charset=cp1251" in head:
        enc = "cp1251"
    elif "charset=utf-8" in head:
        enc = "utf-8"
    else:
        # мета-тегу немає — пробуємо utf-8, інакше cp1251 (типове для судів)
        try:
            body.decode("utf-8")
            enc = "utf-8"
        except UnicodeDecodeError:
            enc = "cp1251"

    html = body.decode(enc, errors="replace")

    # 2. Прибираємо старий charset, щоб браузер не перекодовував UTF-8 як cp1251
    html = re.sub(
        r'<meta[^>]*charset[^>]*>',
        '<meta charset="utf-8">',
        html,
        count=1,
        flags=re.IGNORECASE,
    )
    if "charset" not in html[:2048].lower():
        html = html.replace("<head>", '<head><meta charset="utf-8">', 1)

    # 3. <base href> для відносних ресурсів (герб, CSS)
    if "<base" not in html.lower():
        html = html.replace("<head>", f'<head><base href="{CABINET_URL}/">', 1)

    return html.encode("utf-8"), "text/html; charset=utf-8"


@app.get("/search", response_model=dict)
async def search(
    name: str = Query(..., description="ПІБ особи для пошуку", example="Іваненко Іван Іванович"),
    pages: int = Query(1, ge=1, le=5, description="Кількість сторінок результатів (макс 5)"),
):
    """
    Шукає судові справи за ПІБ в Єдиному реєстрі судових рішень.
    """
    if len(name.strip()) < 3:
        raise HTTPException(status_code=400, detail="ПІБ занадто коротке")

    try:
        result: SearchResult = await search_by_name(name.strip(), max_pages=pages)
    except RuntimeError as e:
        # Реєстр недоступний — окремий статус, щоб клієнт не показував
        # оманливе «нічого не знайдено».
        raise HTTPException(status_code=503, detail=str(e))

    return {
        "query": result.query,
        "total_found": result.total_found,
        "returned": len(result.cases),
        "cases": [
            {
                "case_number": c.case_number,
                "court_name": c.court_name,
                "date": c.date,
                "document_type": c.document_type,
                "url": c.url,
                "excerpt": c.excerpt,
            }
            for c in result.cases
        ],
    }

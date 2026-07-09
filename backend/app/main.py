import os

from fastapi import FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.scraper import search_by_name
from app.cabinet_auth import get_session, clear_session
from app.cabinet_scraper import get_my_cases, get_case_documents, get_document_file, get_calendar_events
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
async def cabinet_document_file(doc_id: str):
    """
    Проксіює файл документа з cabinet.court.gov.ua (рішення/ухвала —
    HTML або PDF). Авторизація (Bearer/cookies) додається на сервері,
    тож клієнт може відкрити цей URL напряму без облікових даних.
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

        return Response(content=body, media_type=content_type)
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

    result: SearchResult = await search_by_name(name.strip(), max_pages=pages)

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

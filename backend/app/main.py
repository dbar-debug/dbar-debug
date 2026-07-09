import os

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from app.scraper import search_by_name
from app.cabinet_auth import get_session, clear_session
from app.cabinet_scraper import get_my_cases
from app.models import SearchResult

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
                }
                for c in result.cases
            ],
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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

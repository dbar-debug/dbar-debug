from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from app.scraper import search_by_name
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


@app.get("/health")
async def health():
    return {"status": "ok"}


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

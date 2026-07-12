"""
Debug: дістає "сирий" JSON руху справи (/api/documents/case) по власних
справах і показує ВСІ поля документів, щоб знайти, де саме лежить дата й
час минулих судових засідань (напр. документи "Внесення дат слухання").

Використання (на сервері, у ~/court-app/backend):
    python3 debug_case_movement.py

Читає KEP_FILE_PATH / KEP_PASSWORD з оточення (як і бекенд). Обробляє
перші кілька справ, друкує:
  * повний набір полів першого документа кожної справи (щоб побачити схему);
  * усі документи, чий опис натякає на засідання/слухання/розгляд — з усіма
    полями, бо саме там має бути дата/час засідання.
Повний дамп також пишеться у debug_output/case_movement.json.
"""

import asyncio
import json
import os
from pathlib import Path

from playwright.async_api import async_playwright

from app.cabinet_auth import get_session

CABINET_URL = "https://cabinet.court.gov.ua"
OUT = Path("debug_output")
OUT.mkdir(exist_ok=True)

MAX_CASES = 5          # скільки справ переглянути
HINTS = ["засідан", "слухан", "розгляд", "призначен", "перерв", "відклад"]


async def main():
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        print("Встанови KEP_FILE_PATH та KEP_PASSWORD у оточенні (як у бекенді).")
        return

    print("[1] Авторизація (кешована сесія, якщо свіжа)...")
    session = await get_session(kep_file, password)
    cookies = session.get("cookies") or []
    token = (session.get("local_storage") or {}).get("token", "")
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    print(f"[OK] cookies: {len(cookies)}, token: {'є' if token else 'нема'}\n")

    dump = []
    async with async_playwright() as pw:
        api = await pw.request.new_context(
            storage_state={"cookies": cookies, "origins": []},
            extra_http_headers=headers,
        )
        try:
            # Список справ
            resp = await api.get(
                f"{CABINET_URL}/api/cases/my",
                params={"start": 0, "count": MAX_CASES, "is_not_deleted": 1},
            )
            cases = (await resp.json()).get("data") or []
            print(f"[2] Оброблю {len(cases)} справ\n")

            for case in cases:
                case_id = case.get("id", "")
                number = case.get("number", "—")
                print(f"=== Справа {number} (id={case_id}) ===")

                resp = await api.get(
                    f"{CABINET_URL}/api/documents/case",
                    params={
                        "case_id": case_id,
                        "start": 0,
                        "count": 100,
                        "sort[docDate]": "desc",
                        "is_not_deleted": 1,
                    },
                )
                docs = (await resp.json()).get("data") or []
                print(f"    документів: {len(docs)}")

                if docs:
                    print("    --- ПОВНІ ПОЛЯ першого документа (схема) ---")
                    print("    " + json.dumps(docs[0], ensure_ascii=False, indent=2).replace("\n", "\n    "))

                # Документи, що схожі на засідання
                hearing_docs = [
                    d for d in docs
                    if any(h in (d.get("description") or "").lower() for h in HINTS)
                ]
                print(f"    подій, схожих на засідання: {len(hearing_docs)}")
                for d in hearing_docs:
                    print("    --- засідання? ПОВНІ ПОЛЯ ---")
                    print("    " + json.dumps(d, ensure_ascii=False, indent=2).replace("\n", "\n    "))

                dump.append({
                    "case_number": number,
                    "case_id": case_id,
                    "documents": docs,
                })
                print()
        finally:
            await api.dispose()

    (OUT / "case_movement.json").write_text(
        json.dumps(dump, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print("Готово. Повний дамп: debug_output/case_movement.json")


asyncio.run(main())

"""
Автентифікація API за спільним токеном.

Кожен запит (крім /health і CORS preflight) має нести токен з env API_TOKEN:
  - заголовок  Authorization: Bearer <token>   (основний спосіб), або
  - заголовок  X-API-Key: <token>, або
  - query-параметр ?key=<token> — лише для посилань, які відкриваються
    напряму в браузері/iframe (файли документів), де заголовок не передати.

Якщо API_TOKEN не задано або він коротший за MIN_TOKEN_LEN — сервер
відмовляє в усіх запитах (fail closed), щоб випадковий запуск без
налаштування не відкрив КЕП-кабінет усьому інтернету.

Згенерувати токен:  python3 -c "import secrets; print(secrets.token_urlsafe(32))"
"""
import hmac
import os

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

MIN_TOKEN_LEN = 32
PUBLIC_PATHS = frozenset({"/health"})


def _supplied_token(request: Request) -> str:
    auth = request.headers.get("authorization", "")
    if auth[:7].lower() == "bearer ":
        return auth[7:].strip()
    api_key = request.headers.get("x-api-key")
    if api_key:
        return api_key.strip()
    return request.query_params.get("key", "")


class TokenAuthMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        if request.method == "OPTIONS" or request.url.path in PUBLIC_PATHS:
            return await call_next(request)

        expected = os.getenv("API_TOKEN", "")
        if len(expected) < MIN_TOKEN_LEN:
            return JSONResponse(
                {"detail": "Сервер не налаштовано: задайте API_TOKEN (≥32 символи) у .env"},
                status_code=503,
            )

        supplied = _supplied_token(request)
        if not supplied or not hmac.compare_digest(
            supplied.encode("utf-8"), expected.encode("utf-8")
        ):
            return JSONResponse(
                {"detail": "Потрібен токен доступу (Налаштування → Токен доступу)"},
                status_code=401,
                headers={"WWW-Authenticate": "Bearer"},
            )

        return await call_next(request)

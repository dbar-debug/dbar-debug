# Court Cases App

Додаток для пошуку судових справ по ПІБ в Єдиному реєстрі судових рішень України.

## Архітектура

```
iPhone (Flutter)  →  Ваш сервер (Ubuntu)  →  reyestr.court.gov.ua
                      FastAPI + Playwright
```

## Запуск бекенду

### Варіант А — локально (для розробки та тестування)

```bash
cd backend

# Встановити залежності
pip install -r requirements.txt

# Встановити браузер Chromium для Playwright
playwright install chromium

# Запустити API
uvicorn app.main:app --reload
```

API буде доступне за адресою: http://localhost:8000

Документація (Swagger UI): http://localhost:8000/docs

### Варіант Б — через Docker (для сервера)

```bash
cd backend

docker-compose up -d
```

## Тест скрапера без API

```bash
cd backend
python -m app.scraper "Іваненко Іван Іванович"
```

## Тест API

```bash
curl "http://localhost:8000/search?name=Іваненко%20Іван%20Іванович"
```

## Особистий кабінет (КЕП-авторизація)

```bash
curl -s http://localhost:8000/cabinet/cases | python3 -m json.tool
```

Потребує `.env` з `KEP_FILE_PATH` і `KEP_PASSWORD` (див.
`backend/.env.example`). Авторизація через `id.gov.ua` (файловий носій,
напр. ПриватБанк) виконується автоматично при першому запиті і кешується на
4 години. Дані справ отримуються напряму з внутрішнього JSON API
`cabinet.court.gov.ua/api/cases/my` — без HTML-скрапінгу.

## Мобільний додаток

Flutter-клієнт для iPhone/Android/Web — див. `mobile/README.md`.

## Структура проєкту

```
backend/
├── app/
│   ├── main.py            # FastAPI маршрути
│   ├── scraper.py         # Playwright-скрапер публічного реєстру
│   ├── cabinet_auth.py    # КЕП-авторизація через id.gov.ua
│   ├── cabinet_scraper.py # Отримання "Моїх справ" через внутрішній API
│   └── models.py          # Моделі даних
├── Dockerfile
├── docker-compose.yml
└── requirements.txt

mobile/
├── lib/
│   ├── main.dart
│   ├── models/court_case.dart
│   ├── services/api_service.dart
│   └── screens/           # Мої справи, Пошук, Налаштування
└── pubspec.yaml
```

## Наступні кроки

- [x] Фаза 2: Авторизація через КЕП (cabinet.court.gov.ua)
- [ ] Фаза 3: Flutter-додаток для iPhone (базовий UI готовий, потребує збірки під iOS)
- [ ] Фаза 4: HTTPS через Nginx + Let's Encrypt на домашньому сервері

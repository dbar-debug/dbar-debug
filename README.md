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

## Структура проєкту

```
backend/
├── app/
│   ├── main.py       # FastAPI маршрути
│   ├── scraper.py    # Playwright-скрапер реєстру
│   └── models.py     # Моделі даних
├── Dockerfile
├── docker-compose.yml
└── requirements.txt
```

## Наступні кроки

- [ ] Фаза 2: Авторизація через КЕП / Дія (cabinet.court.gov.ua)
- [ ] Фаза 3: Flutter-додаток для iPhone
- [ ] Фаза 4: HTTPS через Nginx + Let's Encrypt на домашньому сервері

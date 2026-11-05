FROM python:3.12-slim

# Залежності для Playwright (Chromium)
RUN apt-get update && apt-get install -y \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libpango-1.0-0 libcairo2 libasound2 libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Завантажити Chromium для Playwright
RUN playwright install chromium

# Секрети (.env, sessions/, *.jks) у образ не потрапляють — див. .dockerignore
COPY . .

RUN useradd --create-home app && chown -R app /app
USER app

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]

FROM python:3.12-slim

WORKDIR /srv/pushstats

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

ENV PUSHSTATS_DB=/data/pushstats.db
VOLUME /data
EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]

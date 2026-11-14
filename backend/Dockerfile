FROM python:3.12-slim-bookworm
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
COPY requirements.lock .
RUN pip install --no-cache-dir -r requirements.lock \
    && groupadd --gid 10001 liftlog \
    && useradd --system --no-create-home --uid 10001 --gid 10001 liftlog \
    && mkdir -p /data/media && chown 10001:10001 /data/media
COPY app ./app
COPY alembic.ini .
COPY migrations ./migrations
USER 10001:10001
CMD ["sh","-ec","alembic upgrade head && exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 1 --no-access-log --no-proxy-headers"]

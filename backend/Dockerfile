# Mausam backend — python:3.13-slim, uvicorn on 8000 (05 §Layout).
# Build from the `backend/` directory:  docker build -t mausam-backend .
# Or through the compose file:          cd infra && docker compose up --build

FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8000

WORKDIR /srv

# Dependencies first so a code change does not invalidate the pip layer.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY scripts ./scripts

# `DATABASE_URL=sqlite:///./data/mausam.db` is resolved against the package parent (/srv), so
# the SQLite file lands here. Mount a volume on /srv/data to keep it across restarts.
RUN mkdir -p /srv/data

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=4).status == 200 else 1)"

# Shell form so a platform-provided $PORT (Render, Railway, Fly) is honoured.
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --proxy-headers --forwarded-allow-ips '*'"]

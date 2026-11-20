FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Numeric UID so Kubernetes runAsNonRoot can verify it.
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app

# Dependencies first: code changes reuse this cached layer.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Declared after the dependency layer, so a new version does not invalidate the pip cache.
ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}
LABEL org.opencontainers.image.title="myapp" \
      org.opencontainers.image.version="${APP_VERSION}"

# Owned by root: the app user can read but not modify its code.
COPY main.py .

USER 10001

EXPOSE 8080

# Exec form: uvicorn is PID 1 and receives SIGTERM for graceful shutdown.
# Single worker on purpose: config is stored in process memory.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]

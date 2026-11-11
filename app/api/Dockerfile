# ---- build stage: install dependencies into a virtualenv ----
FROM python:3.12-slim AS build
RUN python -m venv /venv
COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

# ---- runtime stage: small image, non-root user ----
FROM python:3.12-slim
ARG APP_VERSION=dev
ENV PATH=/venv/bin:$PATH PYTHONUNBUFFERED=1 APP_VERSION=$APP_VERSION
COPY --from=build /venv /venv
WORKDIR /app
COPY main.py .
RUN useradd -r -u 10001 app
USER 10001
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]

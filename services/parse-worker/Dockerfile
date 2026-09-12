FROM python:3.12-slim
WORKDIR /app
COPY services/parse-worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY services/parse-worker/app ./app
COPY services/parse-worker/skills ./skills
ENV PYTHONUNBUFFERED=1
EXPOSE 8081
CMD ["python", "-m", "app.main"]

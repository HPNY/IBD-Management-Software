# IBDers 本地开发

.PHONY: install build migrate api worker dev dev-local smoke env-guard

PNPM ?= pnpm
API_PORT ?= 3000
WORKER_PORT ?= 8081

install:
	$(PNPM) install
	cd services/parse-worker && python -m venv .venv || true
	cd services/parse-worker && .venv/bin/pip install -r requirements.txt 2>/dev/null || services/parse-worker/.venv/Scripts/pip install -r requirements.txt

build:
	$(PNPM) --filter @ibd/api build

migrate:
	$(PNPM) --filter @ibd/api migration:run

api:
	node services/api/dist/main.js

worker:
	cd services/parse-worker && PORT=$(WORKER_PORT) .venv/bin/python -m app.main 2>/dev/null || (cd services/parse-worker && PORT=$(WORKER_PORT) .venv/Scripts/python.exe -m app.main)

# 本机 Postgres/Redis 已就绪时
dev-local: build migrate
	@echo "Start API in one terminal: make api"
	@echo "Start Worker in another:    make worker"
	@echo "App: cd apps/mobile && flutter run --dart-define=IBD_API_BASE=http://127.0.0.1:3000"

# 需要 Docker + 根目录 .env（从 .env.example 复制）
dev:
	docker compose up --build

smoke:
	$(PNPM) --filter @ibd/api smoke:env
	$(PNPM) --filter @ibd/api smoke:entities
	$(PNPM) --filter @ibd/api smoke:migration
	$(PNPM) --filter @ibd/api smoke:storage

env-guard:
	$(PNPM) --filter @ibd/api smoke:env

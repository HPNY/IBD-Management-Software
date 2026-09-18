#!/usr/bin/env bash
# CI 全栈：同一脚本内启动 API/Worker 并跑 E2E（避免 Actions 分步杀掉后台进程）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DATABASE_URL="${DATABASE_URL:-postgres://ibd:ibd@127.0.0.1:5432/ibd}"
export REDIS_URL="${REDIS_URL:-redis://127.0.0.1:6379}"
export STORAGE_DRIVER="${STORAGE_DRIVER:-local}"
export STORAGE_LOCAL_DIR="${STORAGE_LOCAL_DIR:-/tmp/ibd-uploads}"
export PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-http://127.0.0.1:3000}"
export STORAGE_SECRET="${STORAGE_SECRET:-ci-storage-secret}"
export RUN_MIGRATIONS="${RUN_MIGRATIONS:-true}"
export NODE_ENV="${NODE_ENV:-development}"
export PORT="${PORT:-3000}"
export PARSE_WORKER_PORT="${PARSE_WORKER_PORT:-8081}"
export IBD_API_BASE="${IBD_API_BASE:-http://127.0.0.1:3000}"

mkdir -p "$STORAGE_LOCAL_DIR"

echo "==> migrations: API boot runs them when RUN_MIGRATIONS=true"
echo "==> start API :$PORT"
node services/api/dist/main.js > /tmp/ibd-api.log 2>&1 &
API_PID=$!

echo "==> start worker :$PARSE_WORKER_PORT"
(cd services/parse-worker && PORT="$PARSE_WORKER_PORT" python -m app.main > /tmp/ibd-worker.log 2>&1) &
WORKER_PID=$!

cleanup() {
  kill "$API_PID" 2>/dev/null || true
  kill "$WORKER_PID" 2>/dev/null || true
  echo "--- api log ---"; tail -n 40 /tmp/ibd-api.log || true
  echo "--- worker log ---"; tail -n 40 /tmp/ibd-worker.log || true
}
trap cleanup EXIT

echo "==> wait for API health"
ok=0
for i in $(seq 1 60); do
  if curl -sf "$IBD_API_BASE/health" >/tmp/ibd-health.json 2>/dev/null; then
    echo "health: $(cat /tmp/ibd-health.json)"
    ok=1
    break
  fi
  if ! kill -0 "$API_PID" 2>/dev/null; then
    echo "API process died"
    exit 1
  fi
  sleep 1
done
if [ "$ok" != "1" ]; then
  echo "API health check failed"
  exit 1
fi

# 确认迁移表存在（API 已带 RUN_MIGRATIONS=true）
grep -q '"db":"ok"' /tmp/ibd-health.json

echo "==> e2e fullstack"
node services/api/scripts/e2e-fullstack.mjs
echo "==> e2e injection"
node services/api/scripts/e2e-injection.mjs
echo "==> e2e medication"
node services/api/scripts/e2e-medication.mjs
echo "==> e2e backup/ai"
node services/api/scripts/e2e-backup-ai.mjs
echo "ALL E2E OK"

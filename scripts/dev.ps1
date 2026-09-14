# IBDers 本地开发启动（Windows）
# 用法:
#   pwsh scripts/dev.ps1              # 假设本机 Postgres/Redis 已就绪
#   pwsh scripts/dev.ps1 -Docker      # docker compose up
#   pwsh scripts/dev.ps1 -BuildOnly   # 只安装并构建 API

param(
  [switch]$Docker,
  [switch]$BuildOnly,
  [string]$ApiPort = "3000",
  [string]$WorkerPort = "8081"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Find-Pnpm {
  $c = Get-Command pnpm -ErrorAction SilentlyContinue
  if ($c) { return "pnpm" }
  $alt = "C:\Xiaomi MiMo\pnpm.cmd"
  if (Test-Path $alt) { return $alt }
  return "pnpm"
}

if ($Docker) {
  if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example — 请修改密码/密钥后再起生产。" -ForegroundColor Yellow
  }
  docker compose up --build
  exit 0
}

$pnpm = Find-Pnpm
Write-Host "==> install + build API" -ForegroundColor Cyan
& $pnpm install
& $pnpm --filter @ibd/api build
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($BuildOnly) { exit 0 }

# 默认本机端口（与 README / 真机清单一致时可覆盖）
if (-not $env:DATABASE_URL) { $env:DATABASE_URL = "postgres://ibd:ibd@127.0.0.1:5433/ibd" }
if (-not $env:REDIS_URL) { $env:REDIS_URL = "redis://127.0.0.1:6380" }
if (-not $env:STORAGE_DRIVER) { $env:STORAGE_DRIVER = "local" }
if (-not $env:STORAGE_LOCAL_DIR) { $env:STORAGE_LOCAL_DIR = Join-Path $root "var\uploads" }
if (-not $env:PUBLIC_BASE_URL) { $env:PUBLIC_BASE_URL = "http://127.0.0.1:$ApiPort" }
if (-not $env:STORAGE_SECRET) { $env:STORAGE_SECRET = "dev-storage-secret" }
if (-not $env:RUN_MIGRATIONS) { $env:RUN_MIGRATIONS = "true" }
New-Item -ItemType Directory -Force -Path $env:STORAGE_LOCAL_DIR | Out-Null

Write-Host "==> migrations" -ForegroundColor Cyan
& $pnpm --filter @ibd/api migration:run
if ($LASTEXITCODE -ne 0) {
  Write-Host "migration failed — 确认 Postgres 已启动且 DATABASE_URL 正确" -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "==> start API :$ApiPort (新窗口)" -ForegroundColor Cyan
$env:PORT = $ApiPort
Start-Process -FilePath "node" -ArgumentList "services\api\dist\main.js" -WorkingDirectory $root

$venvPy = Join-Path $root "services\parse-worker\.venv\Scripts\python.exe"
if (Test-Path $venvPy) {
  Write-Host "==> start parse-worker :$WorkerPort (新窗口)" -ForegroundColor Cyan
  Start-Process -FilePath $venvPy -ArgumentList "-m","app.main" `
    -WorkingDirectory (Join-Path $root "services\parse-worker") `
    -Environment @{ PORT = $WorkerPort; REDIS_URL = $env:REDIS_URL; STORAGE_DRIVER = $env:STORAGE_DRIVER; STORAGE_LOCAL_DIR = $env:STORAGE_LOCAL_DIR }
} else {
  Write-Host "parse-worker venv 不存在，跳过 Worker（可先 make install）" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "API  http://127.0.0.1:$ApiPort  docs=/docs" -ForegroundColor Green
Write-Host "App  cd apps/mobile && flutter run --dart-define=IBD_API_BASE=http://<局域网IP>:$ApiPort" -ForegroundColor Green
Write-Host "配置  docs/configuration.md" -ForegroundColor Green

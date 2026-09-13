# 生成平台工程并安装依赖（需已安装 Flutter SDK）
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter SDK not found in PATH. Install: https://docs.flutter.dev/get-started/install"
  exit 1
}

# 仅在缺少 android 目录时 create，避免覆盖已有 lib/
if (-not (Test-Path "android")) {
  flutter create --org com.ibd --project-name ibd_mobile .
}

# 确保使用仓库 pubspec（create 可能生成空依赖）
flutter pub get

Write-Host "Done. Run: flutter run --dart-define=IBD_API_BASE=http://10.0.2.2:3000"

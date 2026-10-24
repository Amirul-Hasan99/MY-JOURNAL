@echo off
setlocal
chcp 65001 > nul
title My Journal
cd /d "%~dp0"
if not exist pubspec.yaml (
  echo [ERROR] pubspec.yaml tidak ditemukan.
  exit /b 1
)
if /I "%~1"=="test" goto test
if /I "%~1"=="demo" goto demo
if /I "%~1"=="api" goto api

echo My Journal
echo [1] Jalankan Chrome dengan API lokal (backend harus aktif)
echo [2] Jalankan perangkat terhubung
echo [3] Jalankan demo lokal secara eksplisit
echo [4] Analyze dan test
echo [5] Jalankan API Neon lokal
set /p choice="Pilih [1-5]: "
if "%choice%"=="1" goto chrome
if "%choice%"=="2" goto device
if "%choice%"=="3" goto demo
if "%choice%"=="4" goto test
if "%choice%"=="5" goto api
echo Pilihan tidak valid.
exit /b 1

:chrome
call flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787
exit /b %errorlevel%
:device
call flutter run
exit /b %errorlevel%
:demo
call flutter run -d chrome --dart-define=DEMO_MODE=true
exit /b %errorlevel%
:test
call flutter analyze --no-pub
if errorlevel 1 exit /b %errorlevel%
call flutter test --no-pub --concurrency=1
if errorlevel 1 exit /b %errorlevel%
call flutter test --no-pub --concurrency=1 --dart-define=DEMO_MODE=true test\widget_test.dart
exit /b %errorlevel%
:api
if not exist backend\.env (
  echo [ERROR] backend\.env belum ada. Salin backend\.env.example ke backend\.env dan isi DATABASE_URL yang sudah dirotasi.
  exit /b 1
)
cd /d "%~dp0backend"
if not exist node_modules call npm install
if errorlevel 1 exit /b %errorlevel%
call npm run dev
exit /b %errorlevel%

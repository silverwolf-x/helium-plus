@echo off
rem ============================================================
rem  Helium portable self-updater (loader)
rem  A thin batch entry that delegates everything to update.ps1
rem  (Windows PowerShell 5.1, built into Windows 10/11).
rem
rem  Usage:
rem    update.cmd [--check-only] [https://github.com/owner/repo]
rem    update.cmd owner/repo
rem  Options:
rem    --check-only  only query the latest release, no download/no change
rem ============================================================
setlocal EnableExtensions
chcp 65001 >nul
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=powershell.exe"

set "HUP_SCRIPT_DIR=%~dp0"
set "HUP_CMD_ARGS=%*"
set "HUP_ENGINE=%~dp0update.ps1"
if not exist "%HUP_ENGINE%" (
  echo [error] update.ps1 未找到，请确认便携目录包含 update.cmd 和 update.ps1。 1>&2
  exit /b 6
)

set "ARGS=%*"
if /i "%ARGS%"=="--check-only" set "ARGS=-CheckOnly"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HUP_ENGINE%" %ARGS%
exit /b %ERRORLEVEL%
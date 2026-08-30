@echo off
chcp 65001 >nul
rem Encoding: UTF-8 (code page 65001)
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
rem  Set HUP_NO_PAUSE=1 for unattended/automated invocation.
rem ============================================================
setlocal EnableExtensions
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" set "PS_EXE=powershell.exe"

set "HUP_SCRIPT_DIR=%~dp0"
set "HUP_CMD_ARGS=%*"
set "HUP_ENGINE=%~dp0update.ps1"
if not exist "%HUP_ENGINE%" (
  echo [error] update.ps1 未找到，请确认便携目录包含 update.cmd 和 update.ps1。 1>&2
  set "HUP_EXIT_CODE=6"
  goto :finish
)

set "ARGS=%*"
if /i "%ARGS%"=="--check-only" set "ARGS=-CheckOnly"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HUP_ENGINE%" %ARGS%
set "HUP_EXIT_CODE=%ERRORLEVEL%"

:finish
rem Do not force-close the caller's command window. Double-click users can
rem read the result; automation can set HUP_NO_PAUSE=1.
if /i not "%HUP_NO_PAUSE%"=="1" pause
rem Preserve the updater result without terminating the caller's cmd.exe.
%ComSpec% /d /c exit %HUP_EXIT_CODE%
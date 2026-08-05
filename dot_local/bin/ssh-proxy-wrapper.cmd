@echo off
REM SSH dynamic proxy wrapper (Windows)
REM Proxy source priority:
REM   1. CLASH_SOCKS_PORT (explicit SOCKS port)
REM   2. current shell proxy env vars (ALL_PROXY > HTTPS_PROXY > HTTP_PROXY, lower-case too)
REM   3. fallback 127.0.0.1:7898
REM Use proxy if reachable, otherwise direct connect

setlocal enabledelayedexpansion

set "HOST=%1"
set "PORT=%2"

REM Default fallback
set "PROXY_HOST=127.0.0.1"
set "PROXY_PORT=7898"
set "PROXY_TYPE=socks5"

REM 1. Explicit SOCKS port
if defined CLASH_SOCKS_PORT (
    set "PROXY_PORT=%CLASH_SOCKS_PORT%"
    goto :check_proxy
)

REM 2. Parse proxy from shell env vars (case-insensitive)
set "PROXY_URL="
for %%v in (ALL_PROXY HTTPS_PROXY HTTP_PROXY all_proxy https_proxy http_proxy) do (
    if defined %%v (
        if not defined PROXY_URL set "PROXY_URL=!%%v!"
    )
)

if defined PROXY_URL (
    REM Detect proxy type from scheme
    echo(!PROXY_URL! | findstr /i "socks5://" >nul && set "PROXY_TYPE=socks5"
    echo(!PROXY_URL! | findstr /i "http://" >nul && set "PROXY_TYPE=http"

    REM Strip scheme prefix
    set "PROXY_URL=!PROXY_URL:*://=!"
    REM Strip path part
    for /f "delims=/" %%p in ("!PROXY_URL!") do set "PROXY_URL=%%p"
    REM Split host and port
    for /f "tokens=1,* delims=:" %%a in ("!PROXY_URL!") do (
        set "PROXY_HOST=%%a"
        if not "%%b"=="" set "PROXY_PORT=%%b"
    )
)

:check_proxy
REM Fast proxy availability check via ncat zero-I/O mode (no powershell startup cost)
ncat -z -w 1 %PROXY_HOST% %PROXY_PORT% >nul 2>&1

if %ERRORLEVEL% equ 0 (
  REM Use proxy
  ncat --proxy %PROXY_HOST%:%PROXY_PORT% --proxy-type %PROXY_TYPE% !HOST! !PORT!
) else (
  REM Direct connect
  ncat !HOST! !PORT!
)

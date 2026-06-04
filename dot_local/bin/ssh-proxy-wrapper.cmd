@echo off
REM SSH 动态代理选择脚本 (Windows)
REM 检查 Clash SOCKS5 代理 (127.0.0.1:7898)，有就用，没有就直连

setlocal enabledelayedexpansion

set HOST=%1
set PORT=%2

REM 检查代理是否可用
powershell -NoProfile -Command ^
  "try { ^
    $result = (Test-NetConnection -ComputerName 127.0.0.1 -Port 7898 -WarningAction SilentlyContinue).TcpTestSucceeded; ^
    if ($result) { exit 0 } else { exit 1 } ^
  } catch { exit 1 }"

if %ERRORLEVEL% equ 0 (
  REM 使用 SOCKS5 代理
  ncat --proxy 127.0.0.1:7898 --proxy-type socks5 !HOST! !PORT!
) else (
  REM 直连
  ncat !HOST! !PORT!
)

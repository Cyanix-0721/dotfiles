#!/usr/bin/env pwsh

# 统一日志输出样式（供其他脚本加载）
$Script:CommonLoaded = $true

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message)
    Write-Host "→ $Message…" -ForegroundColor Magenta
}

function Write-Ok {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Err {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Note {
    param([string]$Message)
    Write-Host "∙ $Message" -ForegroundColor Gray
}
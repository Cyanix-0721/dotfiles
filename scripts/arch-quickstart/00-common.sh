#!/bin/bash

# 统一日志输出样式（供其他脚本加载）
export COMMON_LOADED=1

if [ -t 1 ]; then
	RESET="\033[0m"
	BOLD="\033[1m"
	DIM="\033[2m"
	RED="\033[31m"
	GREEN="\033[32m"
	YELLOW="\033[33m"
	BLUE="\033[34m"
	CYAN="\033[36m"
else
	RESET=""
	BOLD=""
	DIM=""
	RED=""
	GREEN=""
	YELLOW=""
	BLUE=""
	CYAN=""
fi

header() { printf "\n%s%s==> %s%s\n" "$BOLD" "$BLUE" "$1" "$RESET"; }
step() { printf "%s→ %s…%s\n" "$CYAN" "$1" "$RESET"; }
ok() { printf "%s✓ %s%s\n" "$GREEN" "$1" "$RESET"; }
warn() { printf "%s⚠ %s%s\n" "$YELLOW" "$1" "$RESET"; }
err() { printf "%s✗ %s%s\n" "$RED" "$1" "$RESET"; }
note() { printf "%s∙ %s%s\n" "$DIM" "$1" "$RESET"; }

# =============================================================================
# CC Switch catalog auto-heal (Codex/WSL)
# =============================================================================
# CC Switch 每次同步会重新生成 ~/.codex/cc-switch-model-catalog.json，并把
# "supports_search_tool" 重置为 true。本文件在每次 fish 提示符出现时做幂等检查，
# 发现 true 即改回 false——被下次同步覆盖后会自动再次修复，无需手动干预。
#
# CC Switch regenerates ~/.codex/cc-switch-model-catalog.json on every sync and
# resets "supports_search_tool" to true. This file idempotently checks on each
# fish prompt and flips it back to false; it self-heals after the next sync.
# Machines without the file (e.g. Arch) no-op silently.

function _heal_cc_catalog --on-event fish_prompt
    # 依赖或目标文件缺失时静默跳过（跨机器安全）
    command -q sed; or return
    set -l catalog "$HOME/.codex/cc-switch-model-catalog.json"
    test -f "$catalog"; or return
    # 已修复（false）时跳过——幂等，避免每个提示符重复写文件
    grep -q '"supports_search_tool": true' "$catalog"; or return
    sed -i 's/"supports_search_tool": true/"supports_search_tool": false/g' "$catalog"
end

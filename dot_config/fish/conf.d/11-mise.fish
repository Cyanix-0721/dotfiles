# mise：交互式 shell 完整激活，非交互式（脚本/cron）用 shims 轻量模式
# mise: full activation for interactive shells, shims mode for non-interactive (scripts/cron)
if status is-interactive
    mise activate fish | source
else
    mise activate fish --shims | source
end

# mise shell 补全 / mise shell completions
if command -q mise
    mise completion fish | source
end

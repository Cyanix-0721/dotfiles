# uv shell 补全 / uv shell completions
if command -q uv
    uv generate-shell-completion fish | source
end

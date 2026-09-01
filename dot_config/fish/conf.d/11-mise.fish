# mise：激活 + shell 补全
# mise: activation + shell completions

mise activate fish | source

# mise shell 补全 / mise shell completions
if command -q mise
    mise completion fish | source
end

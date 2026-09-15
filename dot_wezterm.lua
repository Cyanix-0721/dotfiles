local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local function find_cmd(cmds)
    for _, cmd in ipairs(cmds) do
        local ok, _ = pcall(wezterm.run_child_process, {cmd, '--version'})
        if ok then
            return {cmd}
        end
    end
    -- fallback to the platform's default shell
    return nil
end

local is_windows = wezterm.target_triple:find('windows') ~= nil
if is_windows then
    config.default_prog = find_cmd {'pwsh', 'cmd', 'bash'}
else
    config.default_prog = find_cmd {'fish', 'bash', 'zsh'}
end

config.launch_menu = {}
local shell_entries = is_windows and {{
    label = 'pwsh',
    args = {'pwsh'}
}, {
    label = 'CMD',
    args = {'cmd'}
}, {
    label = 'Bash',
    args = {'bash'}
}} or {{
    label = 'Fish',
    args = {'fish'}
}, {
    label = 'Bash',
    args = {'bash'}
}, {
    label = 'Zsh',
    args = {'zsh'}
}}
for _, entry in ipairs(shell_entries) do
    local ok, _ = pcall(wezterm.run_child_process, {entry.args[1], '--version'})
    if ok then
        table.insert(config.launch_menu, entry)
    end
end

config.color_scheme = 'Tokyo Night'

config.window_background_opacity = 0.8
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

config.font = wezterm.font_with_fallback({'JetBrainsMono Nerd Font Mono', 'Sarasa Mono SC'})
config.font_locator = is_windows and 'Gdi' or 'FontConfig'
config.font_rules = {{
    font = wezterm.font('Sarasa Mono SC'),
    italic = true
}}

config.mouse_bindings = {{
    event = {
        Up = {
            streak = 1,
            button = 'Left'
        }
    },
    mods = 'CTRL',
    action = 'OpenLinkAtMouseCursor'
}}

-- Windows: WezTerm 注入的 SSH_AUTH_SOCK 指向不存在的 unix socket，
-- 反而遮蔽真实的 Windows agent（走命名管道 \\.\pipe\openssh-ssh-agent），
-- 导致 ssh-add / ssh 报 "No such file or directory"。仅 Windows 关闭；
-- Linux/macOS 保留该功能（mux 可跨端转发 agent）。
if is_windows then
    config.mux_enable_ssh_agent = false
end

return config

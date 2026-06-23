local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local function find_cmd(cmds)
  for _, cmd in ipairs(cmds) do
    local ok, _ = pcall(wezterm.run_child_process, { cmd, '--version' })
    if ok then
      return { cmd }
    end
  end
  -- fallback to the platform's default shell
  return nil
end

local is_windows = wezterm.target_triple:find('windows') ~= nil
if is_windows then
  config.default_prog = find_cmd { 'nu', 'pwsh','cmd', 'bash' }
else
  config.default_prog = find_cmd { 'fish', 'nu', 'bash', 'zsh' }
end

config.launch_menu = {}
local shell_entries = is_windows and {
  { label = 'Nushell',    args = { 'nu' } },
  { label = 'PowerShell', args = { 'pwsh' } },
  { label = 'CMD',        args = { 'cmd' } },
  { label = 'Bash',       args = { 'bash' } },
} or {
  { label = 'Fish',       args = { 'fish' } },
  { label = 'Bash',       args = { 'bash' } },
  { label = 'Nushell',    args = { 'nu' } },
  { label = 'Zsh',        args = { 'zsh' } },
}
for _, entry in ipairs(shell_entries) do
  local ok, _ = pcall(wezterm.run_child_process, { entry.args[1], '--version' })
  if ok then
    table.insert(config.launch_menu, entry)
  end
end

config.color_scheme = 'Tokyo Night'

config.window_background_opacity = 0.8
config.window_decorations = "INTEGRATED_BUTTONS|RESIZE"

config.font = wezterm.font('JetBrainsMono Nerd Font Mono')
config.font_locator = is_windows and 'Gdi' or 'FontConfig'
config.font_rules = {
  {
    font = wezterm.font('Sarasa Mono SC'),
    italic = true,
  },
}

config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = 'OpenLinkAtMouseCursor'
  }
}

return config

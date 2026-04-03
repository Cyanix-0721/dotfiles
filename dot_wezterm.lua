local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find('windows') ~= nil
config.default_prog = { is_windows and 'nu.exe' or 'nu' }

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

return config

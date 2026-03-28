local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find('windows') ~= nil
config.default_prog = { is_windows and 'nu.exe' or 'nu' }

return config

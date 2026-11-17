-- Annihilation: the Omarchy theme's palette as a Neovim colorscheme. No options: the palette
-- is fixed and the groups are plain (a background-stripping script, such as a transparency
-- one, can take the backgrounds off).
local M = {}

-- Plugin groups are all defined, whether or not the plugin is installed: a group nobody
-- draws costs nothing, and a lazy-loaded plugin would otherwise draw before its group exists.
local modules = { "editor", "syntax", "lsp", "plugins" }

function M.load()
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
  vim.o.termguicolors = true
  vim.o.background = "dark"
  vim.g.colors_name = "annihilation"

  local c = require("annihilation.palette")
  for _, name in ipairs(modules) do
    for group, hl in pairs(require("annihilation.groups." .. name)(c)) do
      vim.api.nvim_set_hl(0, group, type(hl) == "string" and { link = hl } or hl)
    end
  end

  -- The same sixteen as the terminal themes Omarchy generates.
  local ansi = {
    c.bg, c.red, c.moss, c.amber, c.rose, c.mauve, c.teal, c.fg,
    c.muted, c.rose, c.bright_moss, c.light_fg, c.bright_rose, c.bright_mauve, c.bright_teal, c.bright_fg,
  }
  for i, color in ipairs(ansi) do
    vim.g["terminal_color_" .. (i - 1)] = color
  end
end

return M

-- Lualine finds this by the colorscheme's name (LazyVim sets theme = "auto"). The mode block
-- is the only colour: teal at rest, and the marsh's own hues for the other modes.
local c = require("annihilation.palette")

local function mode(color)
  return {
    a = { fg = c.selection_fg, bg = color, gui = "bold" },
    b = { fg = c.fg, bg = c.lighter_bg },
    c = { fg = c.dark_fg, bg = c.dark_bg },
  }
end

return {
  normal = mode(c.teal),
  insert = mode(c.bright_moss),
  visual = mode(c.bright_mauve),
  replace = mode(c.rose),
  command = mode(c.amber),
  terminal = mode(c.bright_teal),
  inactive = {
    a = { fg = c.comment, bg = c.dark_bg },
    b = { fg = c.comment, bg = c.dark_bg },
    c = { fg = c.comment, bg = c.dark_bg },
  },
}

-- The palette, kept in step with ../../../colors.toml (extras/dev/nvim-test.lua checks it).
-- Names follow colors.toml, not the roles Swamp Dark gives its base16 slots: `blue` is the
-- rose, `red` the crimson, `yellow` and `orange` the same amber.
local M = {
  bg = "#242015",
  dark_bg = "#1E1B1D",
  darker_bg = "#1A1518",
  darkest_bg = "#1C1018",
  lighter_bg = "#3A3124",

  fg = "#D2C3A4",
  dark_fg = "#B8A58C",
  light_fg = "#EBE0BB",
  bright_fg = "#F1E9D0",
  muted = "#5F4E41",
  brown = "#4D3F32",

  red = "#A82D56",
  amber = "#DB930D",
  moss = "#7A7653",
  teal = "#61A0A8", -- the Shimmer, and the accent
  rose = "#C1666B",
  mauve = "#91506C",

  bright_moss = "#9A9669",
  bright_teal = "#84BDC4",
  bright_rose = "#D98388",
  bright_mauve = "#B06C8A",

  selection = "#4D3F32",
  selection_fg = "#242015",
  none = "NONE",
}

local function rgb(hex)
  hex = hex:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

--- `a` toward `b` by `t` (0 is `a`, 1 is `b`).
function M.mix(a, b, t)
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  return string.format(
    "#%02X%02X%02X",
    math.floor(ar + (br - ar) * t + 0.5),
    math.floor(ag + (bg - ag) * t + 0.5),
    math.floor(ab + (bb - ab) * t + 0.5)
  )
end

--- A faint wash of `color` over the editor background, for diff and diagnostic lines.
function M.tint(color, t)
  return M.mix(M.bg, color, t)
end

-- Derived. The comment is the muted brown lifted to about 3.5:1 on the background (the raw
-- muted is 2:1, too faint to read as code); punctuation sits between it and the text.
M.comment = M.mix(M.muted, M.dark_fg, 0.4)
M.faint = M.mix(M.muted, M.comment, 0.5) -- for NonText, which plugins also use for dim file names
M.punct = M.mix(M.bg, M.fg, 0.6)
M.error = M.mix(M.red, M.bright_fg, 0.25) -- the crimson lifted to about 3.8:1
M.cursorline = M.mix(M.bg, M.lighter_bg, 0.55)
M.border = M.mix(M.bg, M.teal, 0.45) -- the Shimmer at the edge of a float

return M

-- Checks for extras/nvim, run headless by extras/dev/nvim-test.sh:
--   nvim --headless -u NONE --cmd "set rtp^=extras/nvim" -l extras/dev/nvim-test.lua
local fails = 0
local function check(ok, msg)
  if not ok then
    fails = fails + 1
    io.stderr:write("FAIL  " .. msg .. "\n")
  end
end

local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")

-- The palette is colors.toml's, name for name.
local toml = {}
for key, hex in io.open(repo .. "/colors.toml"):read("*a"):gmatch('\n([%w_]+) = "(#%x+)"') do
  toml[key] = hex:upper()
end
local p = require("annihilation.palette")
local same = {
  bg = "background", dark_bg = "dark_background", darker_bg = "darker_background",
  darkest_bg = "darkest_background", lighter_bg = "lighter_background",
  fg = "foreground", dark_fg = "dark_foreground", light_fg = "light_foreground",
  bright_fg = "bright_foreground", muted = "muted", brown = "brown", red = "red",
  amber = "yellow", moss = "green", teal = "cyan", rose = "blue", mauve = "magenta",
  bright_moss = "bright_green", bright_teal = "bright_cyan", bright_rose = "bright_blue",
  bright_mauve = "bright_magenta", selection = "selection", selection_fg = "selection_foreground",
}
for name, key in pairs(same) do
  check(toml[key] ~= nil, "colors.toml has no " .. key)
  check(p[name] == toml[key], ("palette.%s = %s, colors.toml %s = %s"):format(name, p[name], key, toml[key]))
end
check(p.amber == toml.orange, "orange and yellow differ in colors.toml; the palette has one amber")
check(p.teal == toml.accent, "accent is not the teal")

-- Contrast on the background: text groups stay readable.
local function lum(hex)
  local out = {}
  for i = 2, 6, 2 do
    local v = tonumber(hex:sub(i, i + 1), 16) / 255
    out[#out + 1] = v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end
  return 0.2126 * out[1] + 0.7152 * out[2] + 0.0722 * out[3]
end
local function ratio(a, b)
  local la, lb = lum(a), lum(b)
  if la < lb then la, lb = lb, la end
  return (la + 0.05) / (lb + 0.05)
end

vim.cmd.colorscheme("annihilation")
check(vim.g.colors_name == "annihilation", "colors_name is " .. tostring(vim.g.colors_name))
check(vim.o.background == "dark", "background is " .. vim.o.background)

local function fg(name)
  local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
  return hl.fg and ("#%06X"):format(hl.fg)
end
for _, name in ipairs({
  "Normal", "Comment", "String", "Number", "Function", "Keyword", "Type", "Operator",
  "@variable", "@variable.member", "@punctuation.bracket", "@markup.heading.1", "LineNr",
  "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo", "DiagnosticHint", "Directory",
  "NonText", "@comment.documentation",
}) do
  local color = fg(name)
  check(color ~= nil, name .. " has no foreground")
  -- NonText and line numbers are chrome, not code: 2.5:1 is enough there.
  local floor = (name == "NonText" or name == "LineNr") and 2.5 or 3.4
  if color then check(ratio(color, p.bg) >= floor, ("%s %s on bg is %.2f:1, under %.1f"):format(name, color, ratio(color, p.bg), floor)) end
end

-- Every group is a table or a link to a group that exists, and a link that points
-- at itself or in a loop would resolve to nothing.
local count = 0
for _, mod in ipairs({ "editor", "syntax", "lsp", "plugins" }) do
  for group, hl in pairs(require("annihilation.groups." .. mod)(p)) do
    count = count + 1
    if type(hl) == "string" then
      check(hl ~= group, group .. " links to itself")
      local target = vim.api.nvim_get_hl(0, { name = hl, link = false })
      check(next(target) ~= nil or hl == "@none", ("%s links to %s, which is not defined"):format(group, hl))
    else
      check(type(hl) == "table", group .. " is neither a table nor a link")
    end
  end
end
check(count > 400, "only " .. count .. " groups defined")

check(vim.g.terminal_color_0 == p.bg and vim.g.terminal_color_15 == p.bright_fg, "terminal colours not set")
check(type(require("lualine.themes.annihilation").normal.a.bg) == "string", "lualine theme did not load")

-- Loading after another scheme leaves nothing of it behind: every group has the
-- attributes a reload gives (a cleared group stays listed, empty, which is fine).
local function snapshot()
  local out = {}
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    if next(hl) ~= nil then out[name] = hl end
  end
  return out
end
vim.cmd.colorscheme("annihilation") -- once more: the first load can turn syntax on
local fresh = snapshot()
vim.cmd.colorscheme("habamax")
check(not vim.deep_equal(fresh, snapshot()), "habamax changed nothing, so this check proves nothing")
vim.cmd.colorscheme("annihilation")
local after = snapshot()
for name, hl in pairs(after) do
  check(vim.deep_equal(fresh[name], hl), name .. " differs after habamax -> annihilation")
end
for name in pairs(fresh) do
  check(after[name] ~= nil, name .. " is missing after habamax -> annihilation")
end

if fails > 0 then
  io.stderr:write(("%d failed\n"):format(fails))
  vim.cmd("cquit 1")
end
print(("nvim colorscheme: ok (%d groups)\n"):format(count))
vim.cmd("quit")

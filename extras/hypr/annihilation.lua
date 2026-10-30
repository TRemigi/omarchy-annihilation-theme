-- Annihilation extras for Hyprland. Omarchy drops *.lua from themes installed
-- out of a git repo, so this can't ship inside the theme. extras/hooks/theme-set.sh
-- loads it after `omarchy theme set annihilation`, and the next theme switch
-- restages hyprland.lua without it.
--
-- The border gradient comes from colors.toml via the generated hyprland.lua, so
-- it is not repeated here. This file adds the slow rotation, the teal halo,
-- blur and the gentler open/close motion. Every period is long on purpose.

hl.config({
  decoration = {
    rounding = 4,

    -- Light through water: a faint teal halo on the focused window, a dark
    -- marsh shadow on the rest.
    shadow = {
      enabled = true,
      range = 18,
      render_power = 3,
      color = "rgba(61a0a822)",
      color_inactive = "rgba(13110955)",
    },

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      vibrancy = 0.25,
      noise = 0.02,
      new_optimizations = true,
    },

    dim_inactive = true,
    dim_strength = 0.06,
  },
})

-- Frost the shell surfaces so the translucent backgrounds in shell.toml read as
-- marsh mist. omarchy-background is deliberately absent.
hl.layer_rule({
  match = { namespace = "^(omarchy-bar|omarchy-menu|omarchy-notifications|omarchy-osd|omarchy-polkit|omarchy-reminders|omarchy-clipboard|omarchy-emojis|omarchy-image-selector)$" },
  blur = true,
  ignore_alpha = 0.3,
})

-- The shimmer wallpaper layer should appear and vanish without a fade.
hl.layer_rule({ match = { namespace = "annihilation-shimmer" }, no_anim = true, animation = "none" })

hl.curve("tendril", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("exhale", { type = "bezier", points = { { 0.5, 0 }, { 0.75, 1 } } })
hl.curve("drift", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- One full turn of the border gradient per minute (speed is in deciseconds).
hl.animation({ leaf = "borderangle", enabled = true, speed = 600, bezier = "drift", style = "loop" })

-- Windows bloom in slowly and recede a little faster.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5.5, bezier = "tendril", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "exhale", style = "popin 92%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3, bezier = "tendril" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2.5, bezier = "exhale" })

hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "tendril", style = "slidefade 12%" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 5, bezier = "tendril", style = "fade" })

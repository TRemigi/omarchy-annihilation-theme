#!/bin/bash

# Omarchy theme-set hook for the Annihilation extras. Linked into
# ~/.config/omarchy/hooks/theme-set.d/ by extras/install, never copied, so the
# repo path below is resolved from this file's real location.
#
# For the annihilation theme it
#   - loads the Hyprland extras (Omarchy reloads Hyprland before it runs theme
#     hooks, so this reloads again after adding the line), and
#   - turns off Omarchy's text screensaver, which the Area X plugin replaces, and
#   - swaps the Neovim spec Omarchy generated (aether.nvim in this palette) for the
#     colorscheme in extras/nvim.
# For any other theme it puts the stock screensaver back, but only if this hook
# is the one that turned it off.
#
# `theme-set.sh --restore` puts the screensaver and the Neovim spec back on its own (used by unlink).
# It always exits 0: a failing theme-set hook aborts the runner, and these
# extras are cosmetic.

THEME=$1
REPO=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
EXTRAS=$REPO/extras/hypr/annihilation.lua
STAGED=$HOME/.local/state/omarchy/current/theme/hyprland.lua
MARK="-- annihilation-extras"

NVIM_SRC=$REPO/extras/nvim
NVIM_STAGED=$HOME/.local/state/omarchy/current/theme/neovim.lua
# Omarchy's own spec for this theme, kept while ours is staged so unlink can put it back.
NVIM_STOCK=$HOME/.local/state/annihilation-theme/neovim.lua.stock

PLUGIN=$HOME/.config/omarchy/plugins/annihilation.area-x
MARKER=$HOME/.local/state/annihilation-theme/screensaver-off-by-us

stock_screensaver_off() {
  command -v omarchy-toggle >/dev/null || return 0
  [[ -e $PLUGIN ]] || return 0
  omarchy-toggle-enabled screensaver-off && return 0
  mkdir -p "$(dirname "$MARKER")"
  touch "$MARKER"
  omarchy-toggle screensaver-off on
}

stock_screensaver_restore() {
  [[ -f $MARKER ]] || return 0
  omarchy-toggle screensaver-off off
  rm -f "$MARKER"
}

# Omarchy's neovim.lua is a lazy.nvim spec that loads aether.nvim with the theme's colours.
# Ours loads the colorscheme in extras/nvim from this checkout instead, under the name
# "annihilation" (the plugin name is what the theme hot-reload plugin looks up). It is
# rewritten on every theme-set, like the rest of the staged theme, and only when it changed,
# so a Neovim watching the file does not reload for nothing.
nvim_colorscheme() {
  [[ -d $NVIM_SRC && -f $NVIM_STAGED ]] || return 0
  local new=$NVIM_STAGED.annihilation
  if ! grep -qF -- "$MARK" "$NVIM_STAGED"; then
    mkdir -p "$(dirname "$NVIM_STOCK")"
    cp "$NVIM_STAGED" "$NVIM_STOCK"
  fi
  cat >"$new" <<EOF
$MARK: the colorscheme in $NVIM_SRC, in place of aether.nvim
return {
  { "annihilation", dir = [==[$NVIM_SRC]==], name = "annihilation", lazy = false, priority = 1000 },
  { "LazyVim/LazyVim", opts = { colorscheme = "annihilation" } },
}
EOF
  if cmp -s "$new" "$NVIM_STAGED"; then rm -f "$new"; else mv "$new" "$NVIM_STAGED"; fi
}

# Put Omarchy's spec back if ours is the one staged.
nvim_restore() {
  [[ -f $NVIM_STOCK && -f $NVIM_STAGED ]] && grep -qF -- "$MARK" "$NVIM_STAGED" || return 0
  cp "$NVIM_STOCK" "$NVIM_STAGED.annihilation" && mv "$NVIM_STAGED.annihilation" "$NVIM_STAGED"
  rm -f "$NVIM_STOCK"
}

if [[ $THEME != annihilation ]]; then
  stock_screensaver_restore
  # Another theme's spec is staged fresh by Omarchy, so there is nothing of ours to undo;
  # only unlink (--restore) has to put the current theme's own back.
  if [[ $THEME == --restore ]]; then nvim_restore; else rm -f "$NVIM_STOCK"; fi
  exit 0
fi

stock_screensaver_off
nvim_colorscheme

[[ -f $EXTRAS && -f $STAGED ]] || exit 0

if ! grep -qF -- "$MARK" "$STAGED"; then
  # pcall: a bad extras file must not stop Hyprland loading the rest.
  [[ -z $(tail -c1 "$STAGED") ]] || echo >>"$STAGED"
  printf 'pcall(dofile, "%s") %s\n' "$EXTRAS" "$MARK" >>"$STAGED"
fi

hyprctl reload >/dev/null 2>&1 || true
exit 0

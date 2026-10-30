#!/bin/bash

# Omarchy theme-set hook for the Annihilation extras. Linked into
# ~/.config/omarchy/hooks/theme-set.d/ by extras/install, never copied, so the
# repo path below is resolved from this file's real location.
#
# For the annihilation theme it
#   - loads the Hyprland extras (Omarchy reloads Hyprland before it runs theme
#     hooks, so this reloads again after adding the line), and
#   - turns off Omarchy's text screensaver, which the shimmer plugin replaces.
# For any other theme it puts the stock screensaver back, but only if this hook
# is the one that turned it off.
#
# `theme-set.sh --restore` does the second part on its own (used by unlink).
# It always exits 0: a failing theme-set hook aborts the runner, and these
# extras are cosmetic.

THEME=$1
REPO=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
EXTRAS=$REPO/extras/hypr/annihilation.lua
STAGED=$HOME/.local/state/omarchy/current/theme/hyprland.lua
MARK="-- annihilation-extras"

PLUGIN=$HOME/.config/omarchy/plugins/annihilation.shimmer
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

if [[ $THEME != annihilation ]]; then
  stock_screensaver_restore
  exit 0
fi

stock_screensaver_off

[[ -f $EXTRAS && -f $STAGED ]] || exit 0

if ! grep -qF -- "$MARK" "$STAGED"; then
  # pcall: a bad extras file must not stop Hyprland loading the rest.
  [[ -z $(tail -c1 "$STAGED") ]] || echo >>"$STAGED"
  printf 'pcall(dofile, "%s") %s\n' "$EXTRAS" "$MARK" >>"$STAGED"
fi

hyprctl reload >/dev/null 2>&1 || true
exit 0

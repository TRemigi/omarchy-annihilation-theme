#!/bin/bash

# Omarchy theme-set hook: load the Annihilation Hyprland extras when (and only
# when) the annihilation theme is applied. Linked into
# ~/.config/omarchy/hooks/theme-set.d/ by extras/install, never copied, so the
# repo path below is resolved from this file's real location.
#
# Omarchy reloads Hyprland before it runs theme hooks, so this reloads again
# after adding the line. It always exits 0: a failing theme-set hook aborts
# the runner, and the extras are cosmetic.

THEME=$1
REPO=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
EXTRAS=$REPO/extras/hypr/annihilation.lua
STAGED=$HOME/.local/state/omarchy/current/theme/hyprland.lua
MARK="-- annihilation-extras"

[[ $THEME == annihilation ]] || exit 0
[[ -f $EXTRAS && -f $STAGED ]] || exit 0

if ! grep -qF -- "$MARK" "$STAGED"; then
  # pcall: a bad extras file must not stop Hyprland loading the rest.
  [[ -z $(tail -c1 "$STAGED") ]] || echo >>"$STAGED"
  printf 'pcall(dofile, "%s") %s\n' "$EXTRAS" "$MARK" >>"$STAGED"
fi

hyprctl reload >/dev/null 2>&1 || true
exit 0

#!/bin/bash
# Headless checks of extras/nvim (the colorscheme). Touches nothing outside a temp dir.
set -euo pipefail
REPO=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export XDG_CONFIG_HOME=$T/c XDG_DATA_HOME=$T/d XDG_STATE_HOME=$T/s XDG_CACHE_HOME=$T/k
nvim --headless -u NONE -i NONE --cmd "set rtp^=$REPO/extras/nvim" -l "$REPO/extras/dev/nvim-test.lua"

# ---- the theme-set hook and the installer, in a scratch HOME ----------------------------
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }

export HOME=$T/home
STAGE=$HOME/.local/state/omarchy/current
HOOK=$REPO/extras/hooks/theme-set.sh
stock='return { { "omacom/aether.nvim", name = "aether" }, { "LazyVim/LazyVim", opts = { colorscheme = "aether" } } }'
stage() {   # Omarchy's side of a theme switch: a fresh staged theme with its own spec
  rm -rf "$STAGE/theme"; mkdir -p "$STAGE/theme"
  echo "$1" >"$STAGE/theme.name"
  printf '%s\n' "$stock" >"$STAGE/theme/neovim.lua"
  echo '-- hyprland' >"$STAGE/theme/hyprland.lua"
}
nv=$STAGE/theme/neovim.lua

stage annihilation
"$HOOK" annihilation
check "hook: spec names the colorscheme" yes "$(grep -q 'colorscheme = "annihilation"' "$nv" && echo yes || echo no)"
check "hook: spec points at extras/nvim" yes "$(grep -qF "[==[$REPO/extras/nvim]==]" "$nv" && echo yes || echo no)"
check "hook: aether.nvim is gone from the spec" no "$(grep -q 'omacom/aether' "$nv" && echo yes || echo no)"
check "hook: the stock spec is kept" "$stock" "$(cat "$HOME/.local/state/annihilation-theme/neovim.lua.stock")"
check "hook: the spec loads as Lua" ok "$(nvim --headless -u NONE -l <(echo 'local t = dofile(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/neovim.lua"); io.write(t[1].name == "annihilation" and t[2].opts.colorscheme == "annihilation" and "ok" or "bad")') 2>&1)"

before=$(stat -c %i "$nv")
"$HOOK" annihilation
check "hook: a second run changes nothing, not even the file" "$before" "$(stat -c %i "$nv")"
check "hook: a second run keeps the stock spec, not ours" "$stock" "$(cat "$HOME/.local/state/annihilation-theme/neovim.lua.stock")"
check "hook: no temp file left" "" "$(ls "$STAGE/theme" | grep annihilation || true)"

out=$("$REPO/extras/install" status)   # not piped into grep -q: it would SIGPIPE status under pipefail
[[ $out == *"neovim    annihilation colorscheme active"* ]] && s=yes || s=no
check "install status: reports the colorscheme" yes "$s"
"$REPO/extras/install" unlink >/dev/null 2>&1
check "install unlink: Omarchy's spec is back" "$stock" "$(cat "$nv")"
check "install unlink: the kept copy is gone" no "$([[ -e $HOME/.local/state/annihilation-theme/neovim.lua.stock ]] && echo yes || echo no)"
out=$("$REPO/extras/install" status)
[[ $out == *"neovim    colorscheme not loaded"* ]] && s=yes || s=no
check "install status: reports it unloaded" yes "$s"

stage annihilation; "$HOOK" annihilation
stage nord; "$HOOK" nord
check "hook: another theme's spec is left as Omarchy staged it" "$stock" "$(cat "$nv")"
check "hook: another theme drops the kept copy" no "$([[ -e $HOME/.local/state/annihilation-theme/neovim.lua.stock ]] && echo yes || echo no)"
"$HOOK" --restore
check "hook --restore: leaves another theme's spec alone" "$stock" "$(cat "$nv")"

stage annihilation; rm "$nv"; "$HOOK" annihilation
check "hook: no staged spec, nothing written" no "$([[ -e $nv ]] && echo yes || echo no)"

echo "hook and installer: $pass passed, $fail failed"
(( fail == 0 ))

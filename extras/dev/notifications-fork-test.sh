#!/bin/bash
# Developer tool, not part of the theme. Tests extras/notifications-fork (status, add, update, enable,
# fallback, remove, auto, and the guard the hooks run) and the installer's hook and subcommand plumbing,
# in a scratch HOME, against fake `omarchy`, `omarchy-shell`, `busctl` and friends. The fake `omarchy`
# changes shell.json the way the real registry does (read from a live config: an enabled clone is in
# plugins[] and cloneSourceRestores, and omarchy.notifications is in disabledPlugins; disabling reverses it).
#
#   bash extras/dev/notifications-fork-test.sh
#
# This tests our logic, not Omarchy's: whether `omarchy plugin disable` really restores the stock daemon
# was confirmed by the user on a real session (docs/theme-integration.md in the fork repo (omarchy-annihilation-notifications)). Each check was also confirmed
# to fail when the code under test was broken on purpose.
set -u

REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../.." && pwd)
FORK=$REPO/extras/notifications-fork
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pass=0 fail=0
check() { if [[ $2 == "$3" ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: want [$2] got [$3]"; fi; }
has() { if [[ $3 == *"$2"* ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: [$3] does not contain [$2]"; fi; }
lacks() { if [[ $3 != *"$2"* ]]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL $1: [$3] contains [$2]"; fi; }

# ------------------------------------------------------------------ fake Omarchy
bin=$tmp/bin; mkdir -p "$bin"
cat >"$bin/omarchy" <<'EOF'
#!/bin/bash
# Fake `omarchy`: records calls and edits shell.json the way the registry does.
echo "omarchy $*" >>"$HOME/.calls"
J=$HOME/.config/omarchy/shell.json
FORK=annihilation.notifications; DIR=$HOME/.config/omarchy/plugins/$FORK
edit() { jq "$1" "$J" >"$J.tmp" && mv "$J.tmp" "$J"; }
case "${1:-} ${2:-}" in
  "plugin add")
    [[ ${FAKE_ADD_RC:-0} == 0 ]] || exit "$FAKE_ADD_RC"
    mkdir -p "$DIR/tools"; echo '{"id":"annihilation.notifications","version":"0.1.0"}' >"$DIR/manifest.json"
    if [[ ${FAKE_NO_TOOLS:-0} != 1 ]]; then printf '#!/bin/bash\nexit $(cat "$HOME/.check-rc")\n' >"$DIR/tools/check-upstream"; chmod +x "$DIR/tools/check-upstream"; fi ;;
  "plugin enable")
    [[ ${3:-} == "$FORK" ]] || exit 0
    [[ ${FAKE_ENABLE_FAIL:-0} == 0 ]] || exit 1
    edit '.plugins = ((.plugins // []) | if map(if type=="object" then .id else . end) | index("annihilation.notifications") then . else . + [{"id":"annihilation.notifications"}] end)
          | .disabledPlugins = (((.disabledPlugins // []) + ["omarchy.notifications"]) | unique)
          | .cloneSourceRestores = (((.cloneSourceRestores // []) + ["annihilation.notifications"]) | unique)' ;;
  "plugin disable"|"plugin remove")
    [[ ${3:-} == "$FORK" ]] || exit 0
    [[ ${FAKE_DISABLE_FAIL:-0} == 0 ]] || exit 1
    [[ ${FAKE_DISABLE_NOOP:-0} == 0 ]] || exit 0
    edit '.plugins = [(.plugins // [])[] | select((if type=="object" then .id else . end) != "annihilation.notifications")]'
    if [[ ${FAKE_STOCK_STAYS_OFF:-0} != 1 ]]; then
      edit '.disabledPlugins = [(.disabledPlugins // [])[] | select(. != "omarchy.notifications")] | .cloneSourceRestores = [(.cloneSourceRestores // [])[] | select(. != "annihilation.notifications")]'
    fi
    [[ $2 == remove ]] && rm -rf "$DIR" ;;
  "plugin update") exit "${FAKE_UPDATE_RC:-0}" ;;
esac
exit 0
EOF
cat >"$bin/omarchy-shell" <<'EOF'
#!/bin/bash
[[ -e $HOME/.shell-down ]] && exit 1
if [[ -e $HOME/.shell-down-for ]]; then   # a shell that comes up after N pings
  n=$(cat "$HOME/.pings" 2>/dev/null || echo 0); echo $((n + 1)) >"$HOME/.pings"
  (( n < $(cat "$HOME/.shell-down-for") )) && exit 1
fi
[[ ${1:-} == shell && ${2:-} == ping ]] && echo ok
exit 0
EOF
cat >"$bin/omarchy-notification-wait" <<'EOF'
#!/bin/bash
[[ -e $HOME/.no-daemon ]] && exit 1
exit 0
EOF
cat >"$bin/omarchy-notification-send" <<'EOF'
#!/bin/bash
echo "$*" >>"$HOME/.notes"
EOF
printf '#!/bin/bash\necho "PID=42"\necho "Comm=quickshell"\n' >"$bin/busctl"
printf '#!/bin/bash\n[[ $1 == -Q ]] && echo "omarchy 4.0.4-1"\n' >"$bin/pacman"
printf '#!/bin/bash\nexit 0\n' >"$bin/sleep"          # the waits are real in production; here they would only slow the tests
printf '#!/bin/bash\nexit 0\n' >"$bin/hyprctl"
chmod +x "$bin"/*
export PATH=$bin:$PATH
unset FAKE_ADD_RC FAKE_NO_TOOLS FAKE_ENABLE_FAIL FAKE_DISABLE_FAIL FAKE_DISABLE_NOOP FAKE_UPDATE_RC FAKE_STOCK_STAYS_OFF GUARD_BOOT_WAIT

# ------------------------------------------------------------------ scenario helpers
n=0
new_env() {
  n=$((n + 1)); H=$tmp/home$n; export HOME=$H
  mkdir -p "$H/.config/omarchy/plugins" "$H/.local/state/annihilation-theme"
  echo '{"version":1,"plugins":[{"id":"vocon"}]}' >"$H/.config/omarchy/shell.json"
  echo 0 >"$H/.check-rc"; : >"$H/.calls"; : >"$H/.notes"
  unset FAKE_ADD_RC FAKE_NO_TOOLS FAKE_ENABLE_FAIL FAKE_DISABLE_FAIL FAKE_DISABLE_NOOP FAKE_UPDATE_RC FAKE_STOCK_STAYS_OFF
}
D() { echo "$HOME/.config/omarchy/plugins/annihilation.notifications"; }
install_fork() { mkdir -p "$(D)/tools"; echo '{"id":"annihilation.notifications","version":"0.1.0"}' >"$(D)/manifest.json"
  printf '#!/bin/bash\nexit $(cat "$HOME/.check-rc")\n' >"$(D)/tools/check-upstream"; chmod +x "$(D)/tools/check-upstream"; }
enable_in_config() { local J=$HOME/.config/omarchy/shell.json
  jq '.plugins += [{"id":"annihilation.notifications"}] | .disabledPlugins=["omarchy.notifications"] | .cloneSourceRestores=["annihilation.notifications"]' "$J" >"$J.t" && mv "$J.t" "$J"; }
set_rc() { echo "$1" >"$HOME/.check-rc"; }
fork_on() { jq -e '(.plugins // []) | map(if type=="object" then .id else . end) | index("annihilation.notifications") != null' "$HOME/.config/omarchy/shell.json" >/dev/null && echo yes || echo no; }
stock_off() { jq -e '(.disabledPlugins // []) | index("omarchy.notifications") != null' "$HOME/.config/omarchy/shell.json" >/dev/null && echo yes || echo no; }
held_kind() { sed -n 's/^kind=//p' "$HOME/.local/state/annihilation-theme/notifications-fork-held" 2>/dev/null; }
calls() { cat "$HOME/.calls"; }
notes() { cat "$HOME/.notes"; }
logtext() { cat "$HOME/.local/state/annihilation-theme/notifications-fork.log" 2>/dev/null; }
run() { out=$("$@" 2>&1); rc=$?; }

# ================================================================== guard
new_env; run "$FORK" guard post-update
check "guard: fork not installed -> nothing" "0|" "$rc|$(calls)"
check "guard: and no log" "" "$(logtext)"

new_env; install_fork; run "$FORK" guard post-update
check "guard: installed but not enabled -> nothing" "0|" "$rc|$(calls)"

new_env; install_fork; enable_in_config; for c in 0 3; do set_rc $c; run "$FORK" guard post-update
  check "guard: in step (exit $c) -> no change" "0|yes|yes|" "$rc|$(fork_on)|$(stock_off)|$(calls)"; done
has "guard: in step is logged" "in step" "$(logtext)"

new_env; install_fork; enable_in_config; set_rc 64; run "$FORK" guard post-boot
check "guard: check says 64 -> left alone" "0|yes|" "$rc|$(fork_on)|$(calls)"
has "guard: and says so in the log" "could not check" "$(logtext)"
new_env; install_fork; enable_in_config; rm "$(D)/tools/check-upstream"; run "$FORK" guard post-boot
check "guard: tool missing -> left alone" "0|yes" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; set_rc 7; run "$FORK" guard post-boot
check "guard: any other exit -> left alone" "0|yes" "$rc|$(fork_on)"

new_env; install_fork; enable_in_config; set_rc 1; run "$FORK" guard post-update
check "guard: vendored file changed -> fell back" "0|no|no|auto" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "guard: it disabled through omarchy" "omarchy plugin disable annihilation.notifications" "$(calls)"
has "guard: reason says the fork copies it" "copies" "$(cat "$HOME/.local/state/annihilation-theme/notifications-fork-held")"
has "guard: reason has the Omarchy version" "4.0.4-1" "$(cat "$HOME/.local/state/annihilation-theme/notifications-fork-held")"
has "guard: the user is told, by notification" "Using the stock notification daemon" "$(notes)"
has "guard: and on the terminal" "Using the stock notification daemon" "$out"
has "guard: the notification says how to get it back" "install notifications update" "$(notes)"
has "guard: it is logged" "fell back to stock (auto)" "$(logtext)"

new_env; install_fork; enable_in_config; set_rc 2; run "$FORK" guard post-boot
check "guard: watched file changed -> fell back" "0|no|no|auto" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "guard: reason says depends on" "depends on" "$(cat "$HOME/.local/state/annihilation-theme/notifications-fork-held")"

new_env; install_fork; enable_in_config; set_rc 1; touch "$HOME/.no-daemon"; run "$FORK" guard post-update
check "guard: no daemon to show a toast -> still falls back" "0|no|no" "$rc|$(fork_on)|$(stock_off)"
check "guard: and sends no notification" "" "$(notes)"

new_env; install_fork; enable_in_config; set_rc 1; "$FORK" auto off >/dev/null; run "$FORK" guard post-update
check "guard: automatic fallback off -> no change" "0|yes|yes" "$rc|$(fork_on)|$(stock_off)"
lacks "guard: and no disable call" "plugin disable" "$(calls)"
has "guard: but the user is told" "Automatic fallback is off" "$(notes)"

new_env; install_fork; enable_in_config; set_rc 1; touch "$HOME/.shell-down"; run "$FORK" guard post-update
check "guard: shell not reachable -> no change, exit 0" "0|yes|" "$rc|$(fork_on)|$(held_kind)"
has "guard: says to run fallback by hand" "install notifications fallback" "$out"
new_env; install_fork; enable_in_config; set_rc 1; touch "$HOME/.shell-down"; GUARD_BOOT_WAIT=0 run "$FORK" guard post-boot
check "guard: post-boot waits for the shell (here 0 s) and gives up cleanly" "0|yes" "$rc|$(fork_on)"

new_env; install_fork; enable_in_config; set_rc 1; FAKE_STOCK_STAYS_OFF=1 run "$FORK" guard post-update
check "guard: fork off but stock still disabled -> exit 0, no marker" "0|no|yes|" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "guard: and it shouts about it" "WARNING" "$out"
has "guard: with the break-glass pointer" "break-glass" "$out"
new_env; install_fork; enable_in_config; set_rc 1; FAKE_DISABLE_FAIL=1 run "$FORK" guard post-update
check "guard: disable fails -> exit 0, nothing recorded" "0|yes|" "$rc|$(fork_on)|$(held_kind)"
has "guard: and says to disable by hand" "omarchy plugin disable" "$out"

new_env; install_fork; enable_in_config; set_rc 1; run "$REPO/extras/hooks/post-update.sh"
check "hook script: post-update falls back" "0|no|auto" "$rc|$(fork_on)|$(held_kind)"
new_env; install_fork; enable_in_config; set_rc 2; mkdir -p "$HOME/.config/omarchy/hooks/post-boot.d"; ln -s "$REPO/extras/hooks/post-boot.sh" "$HOME/.config/omarchy/hooks/post-boot.d/annihilation.sh"
run bash "$HOME/.config/omarchy/hooks/post-boot.d/annihilation.sh"
check "hook script: post-boot through its symlink finds the repo and falls back" "0|no|auto" "$rc|$(fork_on)|$(held_kind)"

# A disabled fork needs no guarding, even when its baseline is stale.
new_env; install_fork; set_rc 1; run "$FORK" guard post-update
check "guard: disabled fork with a stale baseline -> untouched" "0|" "$rc|$(calls)"

# The fork listed as a plain string in shell.json, as the registry also allows.
new_env; install_fork; set_rc 1; jq '.plugins += ["annihilation.notifications"] | .disabledPlugins=["omarchy.notifications"]' "$HOME/.config/omarchy/shell.json" >"$HOME/j" && mv "$HOME/j" "$HOME/.config/omarchy/shell.json"
run "$FORK" guard post-update
check "guard: a string entry counts as enabled" "0|no|no|auto" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"

# A shell that is not up yet when the hook starts.
new_env; install_fork; enable_in_config; set_rc 1; echo 3 >"$HOME/.shell-down-for"; GUARD_BOOT_WAIT=5 run "$FORK" guard post-boot
check "guard: post-boot waits for a shell that comes up late" "0|no|auto" "$rc|$(fork_on)|$(held_kind)"
new_env; install_fork; enable_in_config; set_rc 1; echo 3 >"$HOME/.shell-down-for"; GUARD_BOOT_WAIT=1 run "$FORK" guard post-boot
check "guard: post-boot gives up after its wait" "0|yes" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; set_rc 1; echo 3 >"$HOME/.shell-down-for"; run "$FORK" guard post-update
check "guard: post-update waits a little too" "0|no" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; set_rc 1; echo 30 >"$HOME/.shell-down-for"; run "$FORK" guard post-update
check "guard: but not for long" "0|yes" "$rc|$(fork_on)"

# A disable that reports success but changes nothing.
new_env; install_fork; enable_in_config; set_rc 1; FAKE_DISABLE_NOOP=1 run "$FORK" guard post-update
check "guard: disable did nothing -> no marker, says so, exit 0" "0|yes|" "$rc|$(fork_on)|$(held_kind)"
has "guard: and tells the user to do it by hand" "omarchy plugin disable" "$out"
new_env; install_fork; enable_in_config; FAKE_DISABLE_NOOP=1 run "$FORK" fallback
check "fallback: disable did nothing -> exit 1, no marker" "1|yes|" "$rc|$(fork_on)|$(held_kind)"

# ================================================================== status
new_env; run "$FORK" status
has "status: not installed" "not installed" "$out"; has "status: points at add" "notifications add" "$out"
new_env; install_fork; enable_in_config; run "$FORK" status
has "status: installed, enabled" "installed 0.1.0, enabled" "$out"; has "status: in step" "in step with Omarchy" "$out"
has "status: the Omarchy version" "4.0.4-1" "$out"; has "status: the daemon owner" "quickshell owns" "$out"
has "status: auto fallback on" "auto fallback: on" "$out"; has "status: hooks not linked" "post-update NOT linked" "$out"
run "$FORK" status --short; check "status --short is one line" 1 "$(wc -l <<<"$out")"; has "status --short says enabled" "enabled" "$out"
new_env; install_fork; enable_in_config; set_rc 1; run "$FORK" status
has "status: out of step is shown" "needs a merge" "$out"
new_env; install_fork; set_rc 0; run "$FORK" status
has "status: disabled" "disabled" "$out"
new_env; install_fork; enable_in_config; set_rc 1; "$FORK" guard post-update >/dev/null 2>&1; run "$FORK" status
has "status: held (auto)" "disabled (auto fallback)" "$out"; has "status: shows the reason" "held since" "$out"; has "status: says update brings it back" "notifications update" "$out"
new_env; install_fork; enable_in_config; "$FORK" fallback >/dev/null 2>&1; run "$FORK" status
has "status: held (manual) says enable" "notifications enable" "$out"
new_env; install_fork; jq '.disabledPlugins=["omarchy.notifications"]' "$HOME/.config/omarchy/shell.json" >"$HOME/j" && mv "$HOME/j" "$HOME/.config/omarchy/shell.json"; run "$FORK" status
has "status: warns when nothing would run notifications" "no daemon" "$out"
new_env; install_fork; enable_in_config; for h in post-update post-boot; do mkdir -p "$HOME/.config/omarchy/hooks/$h.d"; ln -s "$REPO/extras/hooks/$h.sh" "$HOME/.config/omarchy/hooks/$h.d/annihilation.sh"; done; run "$FORK" status
has "status: hooks linked" "post-update linked, post-boot linked" "$out"

# ================================================================== add
new_env; touch "$HOME/.shell-down"; run "$FORK" add
check "add: shell not running -> exit 1, nothing tried" "1|" "$rc|$(calls)"
new_env; run "$FORK" add
check "add: succeeds" "0|yes|yes|" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "add: used omarchy plugin add with the URL" "omarchy plugin add https://github.com/TRemigi/omarchy-annihilation-notifications.git --yes" "$(calls)"
has "add: enabled it afterwards" "omarchy plugin enable annihilation.notifications" "$(calls)"
has "add: tells the user to restart the shell" "omarchy restart shell" "$out"
lacks "add: does not restart unasked" "omarchy restart shell" "$(calls)"
new_env; run "$FORK" add --restart; has "add --restart restarts the shell" "omarchy restart shell" "$(calls)"
new_env; set_rc 3; run "$FORK" add
check "add: only the version differs (exit 3) -> enabled" "0|yes" "$rc|$(fork_on)"
new_env; set_rc 1; run "$FORK" add
check "add: out of step -> installed but not enabled, exit 0" "0|no|no|auto" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
lacks "add: never called enable" "plugin enable" "$(calls)"; has "add: and says stock is still running" "stock daemon is still running" "$out"
new_env; FAKE_NO_TOOLS=1 run "$FORK" add
check "add: cannot check -> not enabled" "0|no|auto" "$rc|$(fork_on)|$(held_kind)"
new_env; install_fork; run "$FORK" add
check "add: already installed -> no second add" "0|" "$rc|$(grep -c 'plugin add' "$HOME/.calls" | sed 's/^0$//')"
has "add: says so" "already installed" "$out"
new_env; FAKE_ADD_RC=1 run "$FORK" add; check "add: plugin add fails -> exit 1" "1|no" "$rc|$(fork_on)"
new_env; FAKE_ENABLE_FAIL=1 run "$FORK" add; check "add: enable fails -> exit 1, says how to retry" "1|yes" "$rc|$([[ $out == *'omarchy plugin enable'* ]] && echo yes || echo no)"

# ================================================================== update
new_env; run "$FORK" update; check "update: not installed -> exit 1" 1 "$rc"
new_env; install_fork; enable_in_config; run "$FORK" update
check "update: enabled and in step" 0 "$rc"; has "update: ran omarchy plugin update" "omarchy plugin update annihilation.notifications --yes" "$(calls)"; has "update: reports in step" "in step" "$out"
new_env; install_fork; enable_in_config; set_rc 1; run "$FORK" update
check "update: enabled but out of step -> warns, changes nothing, exit 0" "0|yes" "$rc|$(fork_on)"; has "update: the warning" "WARNING" "$out"
new_env; install_fork; enable_in_config; set_rc 1; "$FORK" guard post-update >/dev/null 2>&1; set_rc 0; run "$FORK" update
check "update: comes back from an automatic fallback once in step" "0|yes|yes|" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "update: says to restart the shell" "omarchy restart shell" "$out"
new_env; install_fork; enable_in_config; set_rc 1; "$FORK" guard post-update >/dev/null 2>&1; set_rc 3; run "$FORK" update
check "update: exit 3 is in step too" "0|yes|" "$rc|$(fork_on)|$(held_kind)"
new_env; install_fork; enable_in_config; set_rc 1; "$FORK" guard post-update >/dev/null 2>&1; run "$FORK" update
check "update: still out of step -> stays on stock, held" "0|no|auto" "$rc|$(fork_on)|$(held_kind)"; has "update: says nothing to do yet" "Nothing to do until" "$out"
new_env; install_fork; enable_in_config; "$FORK" fallback >/dev/null 2>&1; run "$FORK" update
check "update: a manual fallback is not undone" "0|no|manual" "$rc|$(fork_on)|$(held_kind)"; has "update: says to use enable" "notifications enable" "$out"
new_env; install_fork; run "$FORK" update; check "update: disabled and not held stays disabled" "0|no" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; FAKE_UPDATE_RC=1 run "$FORK" update; check "update: plugin update fails -> exit 1" 1 "$rc"
has "update: and hints at remove and add for a rewritten history" "cannot fast-forward" "$out"

# ================================================================== enable
new_env; install_fork; set_rc 1; run "$FORK" enable
check "enable: out of step -> refuses" "1|no" "$rc|$(fork_on)"; has "enable: says why" "needs a merge" "$out"
run "$FORK" enable --force; check "enable --force overrides" "0|yes" "$rc|$(fork_on)"
new_env; install_fork; set_rc 1; "$FORK" guard post-update >/dev/null 2>&1; : ; new_env; install_fork; enable_in_config; "$FORK" fallback >/dev/null 2>&1; run "$FORK" enable
check "enable: after a manual fallback, in step -> on, held cleared" "0|yes|" "$rc|$(fork_on)|$(held_kind)"
new_env; install_fork; set_rc 3; run "$FORK" enable; check "enable: exit 3 is fine" "0|yes" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; run "$FORK" enable; has "enable: already on" "already enabled" "$out"
new_env; run "$FORK" enable; check "enable: not installed -> exit 1" 1 "$rc"

# ================================================================== fallback
new_env; install_fork; enable_in_config; run "$FORK" fallback
check "fallback: switches to stock" "0|no|no|manual" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
has "fallback: says the fork stays installed" "stays installed" "$out"; check "fallback: the fork is still on disk" yes "$([[ -f $(D)/manifest.json ]] && echo yes || echo no)"
run "$FORK" fallback; has "fallback: again is a no-op" "already on the stock daemon" "$out"
new_env; install_fork; enable_in_config; touch "$HOME/.shell-down"; run "$FORK" fallback
check "fallback: shell down -> exit 1, untouched" "1|yes" "$rc|$(fork_on)"
new_env; install_fork; enable_in_config; FAKE_STOCK_STAYS_OFF=1 run "$FORK" fallback
check "fallback: stock stays disabled -> exit 1 with a warning" "1|yes" "$rc|$([[ $out == *WARNING* ]] && echo yes || echo no)"
new_env; run "$FORK" fallback; check "fallback: not installed -> exit 1" 1 "$rc"

# ================================================================== remove
new_env; install_fork; enable_in_config; run "$FORK" fallback; run "$FORK" enable; run "$FORK" remove
check "remove: uninstalls, restores stock, clears the marker" "0|no|no|" "$rc|$(fork_on)|$(stock_off)|$(held_kind)"
check "remove: the folder is gone" no "$([[ -d $(D) ]] && echo yes || echo no)"
new_env; install_fork; enable_in_config; "$FORK" fallback >/dev/null 2>&1; check "remove: precondition, a manual hold exists" manual "$(held_kind)"; run "$FORK" remove
check "remove: clears a marker that was there" "0|" "$rc|$(held_kind)"
new_env; install_fork; enable_in_config; FAKE_STOCK_STAYS_OFF=1 run "$FORK" remove
check "remove: stock still disabled afterwards -> exit 1 with a warning" "1|yes" "$rc|$([[ $out == *WARNING* ]] && echo yes || echo no)"
new_env; run "$FORK" remove; check "remove: not installed -> exit 1" 1 "$rc"

# A bus that cannot be queried is not the same as nobody owning the name.
new_env; install_fork; enable_in_config; printf '#!/bin/bash\nexit 1\n' >"$tmp/bin/busctl"; run "$FORK" status
has "status: unqueryable bus is said plainly" "could not be queried" "$out"
printf '#!/bin/bash\necho "PID=42"\necho "Comm=quickshell"\n' >"$tmp/bin/busctl"

# ================================================================== auto, usage
new_env; run "$FORK" auto; has "auto: default on" "is on" "$out"
run "$FORK" auto off; run "$FORK" auto; has "auto off sticks" "is off" "$out"
check "auto: written to the config file" "auto_fallback=off" "$(cat "$HOME/.config/omarchy/annihilation-notifications.conf")"
run "$FORK" auto on; run "$FORK" auto; has "auto on" "is on" "$out"
run "$FORK" auto maybe; check "auto: junk -> exit 1" 1 "$rc"
run "$FORK" nonsense; check "unknown command -> exit 1" 1 "$rc"; has "usage lists the commands" "status|add|update|enable|fallback|remove|auto|guard" "$out"

# ================================================================== the installer
new_env
run "$REPO/extras/install" link
check "install link: succeeds" 0 "$rc"
for h in theme-set post-update post-boot; do check "install link: $h hook linked" yes "$([[ -L $HOME/.config/omarchy/hooks/$h.d/annihilation.sh ]] && echo yes || echo no)"; done
check "install link: post-update points into the repo" "$REPO/extras/hooks/post-update.sh" "$(readlink -f "$HOME/.config/omarchy/hooks/post-update.d/annihilation.sh")"
run "$REPO/extras/install" status
has "install status: shows the guard hooks" "post-update linked (notification fork guard)" "$out"; has "install status: and the fork line" "notifications fork  not installed" "$out"
run "$REPO/extras/install" link; check "install link: idempotent" 0 "$rc"
run "$REPO/extras/install" unlink
for h in theme-set post-update post-boot; do check "install unlink: $h hook removed" no "$([[ -e $HOME/.config/omarchy/hooks/$h.d/annihilation.sh || -L $HOME/.config/omarchy/hooks/$h.d/annihilation.sh ]] && echo yes || echo no)"; done
new_env; mkdir -p "$HOME/.config/omarchy/hooks/post-boot.d"; echo "# someone else's" >"$HOME/.config/omarchy/hooks/post-boot.d/annihilation.sh"
run "$REPO/extras/install" link
has "install link: refuses to replace a foreign hook" "refusing to replace" "$out"; check "install link: and leaves it alone" "# someone else's" "$(cat "$HOME/.config/omarchy/hooks/post-boot.d/annihilation.sh")"
check "install link: still linked the others" yes "$([[ -L $HOME/.config/omarchy/hooks/post-update.d/annihilation.sh ]] && echo yes || echo no)"
run "$REPO/extras/install" unlink; check "install unlink: leaves the foreign hook" "# someone else's" "$(cat "$HOME/.config/omarchy/hooks/post-boot.d/annihilation.sh")"
new_env; run "$REPO/extras/install" notifications; check "install notifications with no command -> exit 1" 1 "$rc"
run "$REPO/extras/install" notifications status; check "install notifications status works" 0 "$rc"; has "and prints the line" "notifications fork" "$out"
run "$REPO/extras/install" bogus; has "install usage mentions notifications" "notifications <command>" "$out"

echo
if (( fail == 0 )); then echo "ALL $pass CHECKS PASS"; else echo "$fail FAILED, $pass passed"; fi
exit $(( fail ? 1 : 0 ))

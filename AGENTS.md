# AGENTS.md

Guide for an agent continuing work on **omarchy-annihilation-theme**. Read this
before changing anything. `README.md` is the user-facing doc; this file is the
why, the gotchas, and how to verify your work.

## What this is, and the three repos

An [Omarchy](https://omarchy.org/) (Arch + Hyprland + a Quickshell-based shell)
theme themed after *Annihilation* (Alex Garland's 2018 film, from Jeff
VanderMeer's novel). The project is three repos:

| Repo | What it is |
| --- | --- |
| `omarchy-annihilation-theme` (this repo, `~/dev/omarchy-annihilation-theme`) | The theme, and `extras/`: the Hyprland Lua, the theme-set hook and the installer: what neither a theme nor a plugin can carry. |
| `omarchy-area-x` (`~/dev/omarchy-area-x`) | The shell plugin (id `annihilation.shimmer`): the Shimmer layer, window glow, screensaver, bar glyph, notification marks and sound. Installed with `omarchy plugin add`. Its design, gotchas and verification are in **its** `AGENTS.md`; they are not mirrored here. It was `extras/plugin/` in this repo until 2026-11-02 (its history was split out with `git subtree split`). |
| `omarchy-annihilation-notifications` (`~/dev/omarchy-annihilation-notifications`) | A separate plugin: the themed notification daemon and the arrival light. Optional. |

This repo has two tiers:

1. **Portable theme**, at the repo root. Installs with `omarchy theme install`.
2. **Extras**, in `extras/`. The Hyprland Lua and the hooks, symlinked into `~/.config` by
   `extras/install link`, which also adds the plugin from its repo. Omarchy cannot carry these inside a
   repo-installed theme (see Gotchas). Run the installer from the clone Omarchy keeps updated,
   `~/.config/omarchy/themes/annihilation` (what "Extra Themes" in the update menu pulls), so the
   symlinks follow updates.

```
colors.toml            palette (Swamp Dark base16) + hyprland_{active,inactive}_border
shell.toml             hand-tuned shell surfaces; REPLACES the generated one
btop.theme             hand-tuned
unlock.png             the Omarchy wordmark recolored #61A0A8 (disk-unlock screen)
preview-unlock.png     composed mock of the above
backgrounds/           film stills and art (1-, 3- to 5-; 2- and 6- to 9- were dropped), and annihilation-NNN.jpg (20 Blu-ray frames, NNN = frame number): Real-ESRGAN 4x, then downscaled to height 1200 for the 1920x1200 display. Digit-prefixed names sort first, so 1- stays the default
extras/install         link | unlink | status (idempotent bash); adds the plugin with `omarchy plugin add`
extras/hypr/annihilation.lua        border/shadow/blur/dim/animation tweaks
extras/hooks/theme-set.sh           loads the Lua; turns the stock screensaver off (the plugin stands down while it is on)
extras/hooks/post-update.sh, post-boot.sh   run the notification fork's guard (inert unless it is installed and enabled)
extras/dev/notifications-fork-test.sh   tests of the installer and the fork controller
extras/notifications-fork           the fork's controller: status | add | update | enable | fallback | remove | auto | guard
                                    (`extras/install notifications <cmd>` runs it)
```

The Lua's layer rules name the plugin's namespaces (`annihilation-shimmer`, `annihilation-windowglow`); if the plugin
renames one, change `extras/hypr/annihilation.lua` too. The plugin stands down for idle screensaver starts while
Omarchy's own is enabled, and `extras/hooks/theme-set.sh` is what turns Omarchy's off, so keep that hook and the
plugin's check (`stockScreensaverOn` in its `Service.qml`) in step.

**The optional notification daemon** is **a separate project with its own repo**, `github.com/TRemigi/omarchy-annihilation-notifications`
(checked out at `~/dev/omarchy-annihilation-notifications`, with its own `AGENTS.md`, `CONTRACT.md`, plan and runbooks). Its plan, status,
design and releases live there and are **not mirrored or tracked in this repo**; do not copy them back. What this repo has for it is
code and its user-facing instructions: `extras/notifications-fork` (the controller), the `extras/install notifications <command>` wrapper,
the `post-update` and `post-boot` guard hooks that `extras/install link` installs, `extras/dev/notifications-fork-test.sh`, and the README
section "Notification fork (optional)". How the guard works (what it checks, when it switches to the stock daemon, the held marker, the
log, `auto off`) is written up in the fork repo's `docs/theme-integration.md`; read that before changing the controller or the hooks.
The fork reads nothing from this repo. The area-x plugin reads the notification service's state files, so a change to their format in the
fork has to be mirrored there.

Inspiration and context: the film and novel; Swamp Dark base16
(`tinted-theming.github.io/tinted-gallery/#base16-swamp-dark`); the brown marsh with the Shimmer's colours only
at the edges.

## Gotchas (each of these cost real time)

### Omarchy theming

- `omarchy theme install` (any theme dir with `.git`) **drops `*.lua`, terminal
  configs and `vscode.json`**. `hyprland.lua` is regenerated from `colors.toml`
  via `$OMARCHY_PATH/default/themed/*.tpl`. Hence the extras tier.
- `hyprland_active_border` / `hyprland_inactive_border` in `colors.toml` feed
  both the Hyprland and the shell border templates, with no Lua needed.
- A theme's own `shell.toml` replaces the generated one wholesale, so it must
  contain every section (copy `~/.local/state/omarchy/current/theme/shell.toml`
  as a base). Gradient strings use the Hyprland form
  (`"rgba(..) rgba(..) 50deg"`). That form follows the template comments; it was
  never confirmed against the renderer.
- `unlock.png` is the 800x188 Omarchy **wordmark** for the disk-unlock screen,
  not a lock-screen background.
- Never edit `/usr/share/omarchy`. It is read-only reference (and safe to read).
- `omarchy-theme-set` runs `omarchy-restart-hyprctl` **before** the `theme-set`
  hooks, so the hook must `hyprctl reload` again after touching the Lua.
- The `theme-set` runner executes `~/.config/omarchy/hooks/theme-set.d/*.sh` and
  aborts on a non-zero exit. The hook always `exit 0`.
- `omarchy hook install` **copies** the file. We symlink instead so the hook can
  resolve the repo path with `readlink -f`.
- `omarchy-toggle <flag> on|off` is explicit; bare `toggle` flips. The stock
  screensaver is disabled by the flag file `screensaver-off`. The hook sets it
  only while annihilation is active, records a marker
  (`~/.local/state/annihilation-theme/screensaver-off-by-us`), and restores it
  only if it set it. A flag the user set themselves is left alone.

### Hyprland (Lua config, v0.56)

- `hl.animation` **speed is capped at 100** (deciseconds). `borderangle` with
  `style = "loop"` at 100 is the slowest rotation available; the real period is
  unverified. Check with `hyprctl reload && hyprctl configerrors`.
- `windowsOut`/`windowsIn` styles are `popin`/`slide`/`gnomed`, never `fade`.
- Layer rules: `hl.layer_rule({ match = { namespace = ... }, blur = true,
  ignore_alpha = 0.3 })`, plus `no_anim`. Field names come from
  `/usr/share/hypr/stubs/hl.meta.lua` (the best offline API reference). The
  animation functions are not in the stubs; copy usage from
  `/usr/share/omarchy/default/hypr/looknfeel.lua`.
- The extras are appended as `pcall(dofile, "...") -- annihilation-extras` to
  the staged `~/.local/state/omarchy/current/theme/hyprland.lua`. The marker is
  how the hook and installer stay idempotent. It starts with `--`, so use
  `grep -qF -- "$MARK"`.
- Namespaces in play: `omarchy-bar`, `-menu`, `-notifications`, `-osd`,
  `-polkit`, `-reminders`, `-clipboard`, `-emojis`, `-image-selector`,
  `-background`; ours are `annihilation-shimmer` and `annihilation-screensaver`.


## How to verify (this sandbox has no GPU or compositor)

What the agent environment could not do: run Hyprland or Quickshell. The user is the only one who can
confirm anything live. What works:

- Syntax and validation:
  `bash -n extras/install extras/notifications-fork extras/hooks/*.sh`,
  `bash extras/dev/notifications-fork-test.sh` (the fork controller, the guard, the installer's hooks, and how
  it installs, leaves alone and replaces the plugin; every check was confirmed to fail when its code was broken on
  purpose),
  `luac -p extras/hypr/annihilation.lua`,
  `python3 -c 'import tomllib; ...'` for the TOML files.
- Installer and hook: run them with `HOME=$TMPDIR/fakehome` and a copied
  `~/.local/state/omarchy/current/theme/hyprland.lua`. This is how idempotency,
  conflicts and the screensaver marker were tested. The test above stubs `omarchy`, `omarchy-shell` and
  friends, so nothing touches the real shell or plugins.
- The plugin has its own checks (`omarchy plugin validate .`, node logic tests, shader harnesses); see the
  area-x `AGENTS.md`.
- Live checks for the user: `hyprctl configerrors`; `extras/install status`; `omarchy-shell shimmer status`.

## Conventions

- **Do not `git add -A`.** The working tree contains sandbox mounts
  (`.bashrc`, `.gitconfig`, `.idea`, `.zshrc`, ... are character devices) and
  `.claude/`. Add explicit paths, and check `git diff --cached --stat` before committing.
- **When replacing a range of a document, check what the range contains.** A docs edit that cut a
  slice between two markers once deleted a whole section ("How to verify") along with it.
- Small, step-sized commits with a message that says why. Follow whatever
  attribution trailers the session instructions require.
- Preferred voice with the user: concise, honest about what is unverified, no
  repeated permission questions once a direction is agreed.
- Match surrounding code style: terse comments that explain why, no tutorials.


## State

Confirmed by the user by sight: the portable theme and the Hyprland extras.

Open items:

- `preview.png` is missing (needs a real screenshot of the finished desktop;
  the user will supply or take one).
- Border rotation period under the 100-speed cap is unconfirmed; the user may
  prefer it static or slower (a slower version would need the plugin to drive
  the angle itself).
- A themed `[lock]` placeholder phrase was in the original plan and never done.
- The `shell.toml` gradient strings were assumed to work and appeared to, but were never inspected in the source.
- The installer's plugin step (`omarchy plugin add` from the area-x repo) is tested against stubs only; it has
  not been run on a second machine. Until the area-x repo is published, `extras/install link` cannot add the plugin.

## Resources

- Omarchy source (read-only): `/usr/share/omarchy/` (`shell/README.md` for the
  plugin contract and IPC, `default/themed/*.tpl`, `themes/*` for examples,
  `bin/omarchy-theme-set`, `bin/omarchy-theme-update`, `bin/omarchy-plugin-*`). Skill: `omarchy` (Claude
  Code), with `theming.md`, `plugins.md`, `hooks.md`, `hyprland.md`.
- Hyprland: `https://wiki.hypr.land/` (animations, variables) and
  `/usr/share/hypr/stubs/hl.meta.lua`.
- Base16 palette: `https://tinted-theming.github.io/tinted-gallery/#base16-swamp-dark`.

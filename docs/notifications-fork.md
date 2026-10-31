# Plan: the themed notification daemon (a separate repo)

Item 6 of `docs/notifications.md`. This file is the working plan; **update the
Status table and commit it as work proceeds.** The fork itself lives in its own
repo (not started); this repo gets the instructions and the tooling to install,
update and fall back from it.

## Status

| Phase | What | State |
|-------|------|-------|
| P0 | Fork repo exists and is a functional-parity clone of upstream, installable | **done, live-verified 2026-10-30** (`~/dev/omarchy-annihilation-notifications`, pushed) |
| P1 | Update tooling, runbooks and manual fallback (fork repo); installer, README and drift hooks (this repo) | **This repo's side done** (`extras/notifications-fork`, `extras/install notifications ...`, the post-update and post-boot guard hooks, README; 141 checks, 22 breaks caught; not yet seen on a real update). **Fork repo's side partly done in P0**: `check-upstream`, `import-upstream` and their tests, and the runbooks. **Left there:** `contract-check`, `status`, a `fallback` tool, CI |
| P2 | The actual experience: the look (iridescent rim, typography, ring icon), countdown, spores, a switch (theme-gated) | **slice 1 (motion) released as 0.2.0**; look chosen 2026-10-30 (blend of mock-ups A, B and C's spores); **slices 1 to 3 (motion, the look, the countdown) released as 0.2.0 and 0.3.0**, live-verified 2026-10-30; slice 4 (spores) next; Growth kept as a follow-up experiment |
| P3 | Integration with the shimmer plugin, automatic fallback, CI | not started |

This file is mirrored in the fork repo as `docs/plan.md` (the fork's own copy). The fork's phases are
tracked there, this repo's tasks here; when you change one, mirror the other. Do P0 and P1 before any visual work. The point of P0 is to prove the update and
fallback machinery on a fork that changes nothing; features come after.

## What was verified (Omarchy 4.0.4-1, 2026-10-30, by reading `/usr/share/omarchy`)

The whole approach rests on a mechanism Omarchy already has, so these are the facts
to re-check first if anything seems off.

1. **Omarchy has first-class "clone" support.** `omarchy plugin clone <id>` copies a
   built-in plugin to `~/.config/omarchy/plugins/<user>.<name>/` and sets
   `"omarchy": { "clonedFrom": "<builtin id>" }` in its manifest. The shell's
   `PluginRegistry` then: routes calls made to the built-in id to the enabled clone
   (`resolveEnabledId`, used by `firstPartyServiceFor`, `summon`, IPC), adds the
   built-in to `disabledPlugins[]` when a clone with a non-widget kind is enabled
   (so only one daemon runs), and **restores the built-in when the clone is
   disabled or removed** (`restoreCloneSource`, `cloneSourceRestores`). Source:
   `shell/services/PluginRegistry.qml` (about lines 170-182, 420-440, 484-560).
2. **A standalone repo can be that clone.** A manifest copied from
   `plugins/notifications/manifest.json` with a new `id` and
   `omarchy.clonedFrom: "omarchy.notifications"` passes `omarchy plugin validate`
   (tried in a scratch copy). `omarchy plugin add <git-url> --enable --yes` clones a
   repo whose root is the plugin into `~/.config/omarchy/plugins/<id>/`, validates it,
   and enables it; `omarchy plugin update` pulls (and shows the diff first). The id
   must not start with `omarchy.`. Clones inherit the source's host capabilities
   (`stampHostCapabilities`); notifications declares none.
3. **The bar's Do Not Disturb button depends on the built-in id.**
   `plugins/bar/indicators/Dnd.qml` calls `bar.shell.firstPartyServiceFor(
   "omarchy.notifications")` and reads `doNotDisturb` / calls `setDoNotDisturb()`;
   `PluginFirstPartyServiceApi.qml` proxies the same two members. Because of (1) this
   lands on the clone, **provided the clone's service exposes the same members.**
4. **Other things call the daemon.** IPC target `notifications` with `dndState,
   toggleDnd, setDnd, isDnd, showHistory, clear, dismissAll, dismissOne, invokeLast,
   dismiss, ping` (key bindings in `default/hypr/bindings/utilities.lua`,
   `omarchy-toggle-notification-silencing`, `omarchy-notification-dismiss`,
   `omarchy-notification-wait`); `omarchy-notification-send` calls the D-Bus
   `Notify` method directly with hints (`omarchy-action`, glyph, exec argv).
   The state files in `~/.local/state/omarchy/notifications/` (+ `history/`,
   `images/`) are read by **this theme's** feed, tracker and glow.
5. **The built-in is a normal first-party plugin, 1,738 lines:** `Service.qml`
   (1063), `NotificationLogic.js` (479), `components/NotificationCard.qml` (196),
   `manifest.json` (`keepLoaded: true`). It imports `qs.Commons` (Style, Color,
   Border) and `qs.Ui` (BorderSurface), which a third-party plugin can also import
   (this theme's plugin does).
6. **Omarchy ships as a pacman package** (`omarchy 4.0.4-1`, MIT, upstream
   `https://github.com/basecamp/omarchy`); `/usr/share/omarchy` is not a git
   checkout, so "what upstream is" for a given user is the installed files.
   `omarchy-update` runs `omarchy-hook post-update` after the system packages and
   migrations, before the final restart prompt; `omarchy-hook post-boot` runs about
   2 s after Hyprland starts. Hooks are `~/.config/omarchy/hooks/<name>.d/*`.
7. **The dangerous failure.** If the clone is enabled and its QML fails to load
   (for example upstream renamed something in `qs.Commons`), the built-in is
   already disabled, so **there is no notification daemon at all** and the DND
   button is dead. This is why fallback is a first-class requirement, not polish.

Not verified and to be tested live in P0 (the sandbox has no compositor): that
disabling the clone really brings the built-in back with no restart or only
`omarchy restart shell`; the D-Bus hand-over when the shell reloads; that DND state
and `omarchy-notification-send` work through the clone.

## Decisions

- **Mechanism:** a separate repo that is a registered clone of
  `omarchy.notifications` (items 1 and 2), not a patch applied to
  `/usr/share/omarchy` (read-only, overwritten by pacman) and not a rewrite.
- **Name:** repo `omarchy-annihilation-notifications`, plugin id
  `annihilation.notifications`. Confirm the owner and visibility with the user
  before creating anything on GitHub (outward-facing).
- **Phasing:** parity first (P0), then tooling (P1), then features (P2).
- **Theme gating:** the fork is installed globally (enabling a clone is not
  per-theme) and behaves **exactly like stock unless the active theme is
  annihilation**, read the way the shimmer plugin reads
  `~/.local/state/omarchy/current/theme.name`. Considered and rejected for v1:
  swapping daemons from the `theme-set` hook. It would restart the notification
  server on every theme change, with a window where two servers could contend for
  the D-Bus name. Revisit if running fork code on other themes proves a problem.
- **Keep the contracts, so the two repos stay independent:** the fork keeps the IPC
  target and its function names, the `doNotDisturb`/`setDoNotDisturb` members, the
  state-file formats and the `omarchy-notifications` layer namespace (the theme's
  Hyprland blur rule matches it). The shimmer plugin must keep working on stock and
  on the fork; anything fork-only it uses has to degrade when absent.
- **Vendor-branch workflow for upstream** (below), so merges are real git 3-way
  merges with history, not hand-patching.
- **Safe by default:** when upstream changes in a way that touches the fork, fall
  back to stock rather than risk no daemon. The user loses the fancy cards until the
  fork catches up; they never lose notifications.
- **License:** the fork derives from MIT code, so it carries Omarchy's MIT licence
  text and copyright notice (`LICENSE` plus a `NOTICE` saying what it derives from
  and from which version).

## The fork repo

```
manifest.json            id annihilation.notifications, omarchy.clonedFrom, version
Service.qml              forked from upstream (the daemon)
NotificationLogic.js     forked from upstream
components/              forked from upstream (NotificationCard.qml) + new components
UPSTREAM                 generated, edited only on the upstream branch: omarchy version and the
                         sha256 of every vendored file AND of every watched dependency (below)
reference/omarchy/       the watched files themselves (or excerpts of them), also only on upstream,
                         so a change can be read as a diff
CONTRACT.md              the surface this fork must preserve (items 3 and 4 above), with
                         where each piece is checked
LICENSE, NOTICE
AGENTS.md                same role as this repo's: rules, gotchas, how to verify
README.md                what it is, install, update, fallback, uninstall, warning that
                         plugins run unsandboxed
docs/runbooks/           update-from-upstream.md, fallback.md, release.md,
                         live-checklist.md, troubleshooting.md
tools/                   lib.sh, import-upstream, check-upstream (P0); contract-check, status,
                         fallback (P1)
test/                    logic-test.js (NotificationLogic), tools-test.sh (the tools)
docs/releases.md         which Omarchy versions each release was verified against
```

Branches: **`upstream`** holds only pristine copies of the vendored files, one commit
per Omarchy version, tagged `upstream/<omarchy-version>`. **`main`** is the fork.
The first commit on `main` is the merge of `upstream` plus the manifest change, so
the diff between `upstream` and `main` is always exactly "what we changed".

### Updating from upstream (the runbook, in outline)

1. `tools/check-upstream` compares the installed Omarchy (or a ref of
   `basecamp/omarchy`) with `UPSTREAM`. Exit codes: `0` nothing relevant changed;
   `1` a vendored file changed (merge needed); `2` only a dependency file changed
   (review, then maybe bump the baseline); `3` the version changed but every hash
   is the same (safe: bump the supported-versions list).
2. `tools/import-upstream [--from /usr/share/omarchy | --ref <tag>]` writes the new
   pristine files onto `upstream`, updates `UPSTREAM`, commits and tags.
3. `git checkout main && git merge upstream`; resolve conflicts (the runbook lists
   which of our changes sit in which upstream function, so a conflict can be read).
4. `tools/contract-check`: runs `qmllint` on the fork against the **installed**
   `qs.Commons` / `qs.Ui` tree (catches API drift the file hashes cannot, per the
   method in this repo's AGENTS.md), checks that every `omarchy-shell notifications
   <fn>` call found in the installed bins and bindings exists in our `IpcHandler`,
   and that `doNotDisturb` / `setDoNotDisturb` are still exposed.
5. Live checklist (`docs/runbooks/live-checklist.md`): toast, expire, click, dismiss,
   DND on and off, `omarchy-notification-send` (screenshot toast), history replay,
   restart with a live toast, and the theme's own checks.
6. Bump `version` in the manifest, tag a release.

**Watched files** (hashed in `UPSTREAM`; a hash is a tripwire for "changed", not proof
of "broken"; the exact list is `WATCHED` in the fork's `tools/lib.sh`): every file of
Omarchy's notifications plugin (vendored); `Commons/` (`Style`, `Color`, `Border`,
`BorderGeometry.js`, `Util`, `qmldir`) and `Ui/BorderSurface.qml` and `Ui/qmldir`;
`services/PluginFirstPartyServiceApi.qml`; `plugins/bar/indicators/Dnd.qml`; the
`bin/omarchy-notification-*` scripts and `omarchy-toggle-notification-silencing`; and
*excerpts* (only the matching lines, so unrelated edits do not trip it) of
`default/hypr/bindings/utilities.lua` (lines about notifications), `shell.qml`
(`omarchy.notifications` and `firstPartyServiceFor`), and `PluginRegistry.qml` (the
clone machinery: `clonedFrom`, `resolveEnabledId`, `cloneSourceRestores`,
`restoreCloneSource`, `disabledPlugins`); and the list of files in `migrations/` that
mention notifications. Hashes are used, not
version numbers, so a user on a different Omarchy than the maintainer is judged on
what is actually on their disk.

**Also automated, in the fork repo:** a scheduled GitHub Actions workflow fetches
`basecamp/omarchy`'s default branch, runs the same comparison against the `upstream`
branch tip, and opens or updates an issue when the vendored or watched files differ.
(CI cannot run Quickshell, so it only reports; it runs `node` tests, manifest
validation and `qmllint` where it can.)

## Fallback

**Mechanism (verified in the source, to be tested live):** disabling or removing the
clone restores the built-in. So the manual path is

```
omarchy plugin disable annihilation.notifications     # stock notifications return
omarchy restart shell                                  # if the toast layer does not come back
```

and removing the fork entirely is `omarchy plugin remove annihilation.notifications`.

**Break-glass** (when the shell UI is unusable): edit `~/.config/omarchy/shell.json`,
take `annihilation.notifications` out of `plugins[]` and `omarchy.notifications` out
of `disabledPlugins[]` (and its id out of `cloneSourceRestores`), then
`omarchy restart shell`. **Do not just delete or rename the plugin folder:** the
built-in would stay listed in `disabledPlugins[]` and nothing would run. The fork's
`fallback` tool does the right thing for each case and `docs/runbooks/fallback.md`
says why.

**Automatic fallback (P3, design now):**
- A `post-update` and a `post-boot` hook (installed from this repo, as the theme hook
  already is) run `check-upstream`. If a vendored or watched file differs from the
  baseline, the hook disables the fork, writes a marker
  `~/.local/state/annihilation-theme/notifications-fork-held` with the reason, and
  sends a notification once stock has taken over. `post-boot` is what covers updates
  made with plain `pacman` rather than `omarchy-update`. `install notifications
  update` is the way back; it clears the marker once the checks pass. A setting turns
  this off for people who prefer to be told only.
- A watchdog in the **shimmer plugin** (which loads independently of the fork, so it
  still runs when the fork does not): about 10 s after the shell starts, if the fork
  is enabled and nothing owns `org.freedesktop.Notifications` on the session bus
  (`busctl --user status org.freedesktop.Notifications`; `busctl` and `gdbus` are
  present), do the same fallback. This is the guard for the one-way failure in fact 7.

## This repo's side (P1): built

Built as described below, with these differences: the controller is `extras/notifications-fork`
(`extras/install notifications <command>` runs it) and has `enable` and `auto on|off` as well; the fork's own
`status`/`fallback` tools in the fork repo are separate and still to do. See the README section "Notification fork
(optional)" and AGENTS.md for how the guard works. The original design:

- `extras/install notifications <add|update|status|fallback|remove>`: thin wrappers
  over `omarchy plugin add/update/disable/remove` that add what the plain commands do
  not: refuse if the shell is not running, run `check-upstream` before enabling and
  after updating, print the Omarchy version against the fork's baseline, say who owns
  the D-Bus name now, and clear or set the held marker. The fork's URL is one constant
  in the script. `extras/install status` gains a line for it.
- Hooks `extras/hooks/post-update.sh` and `post-boot.sh`, linked and unlinked by
  `extras/install link/unlink` like `theme-set.sh`, always exiting 0. They do nothing
  unless the fork is installed.
- README section "Notification fork (optional)": what it adds, that it replaces the
  stock daemon on every theme though it behaves as stock off this one, that plugins
  run unsandboxed (the warning `omarchy plugin add` itself prints), how to get it,
  update it, fall back, and remove it; and that the theme works the same without it.
- AGENTS.md: a short section pointing here, plus the verified facts above that cost
  time to find.
- The shimmer plugin and this theme are **not** changed to require the fork.

## P0 in detail

**Done (2026-10-30, by the agent):** steps 1 to 5 below, in `~/dev/omarchy-annihilation-notifications`
(a sibling directory, now pushed to the public repo `TRemigi/omarchy-annihilation-notifications`, which the user created because the agent's sandbox could not). `upstream` holds the
pristine 4.0.4-1 files with tag `upstream/4.0.4-1`; `main` is that plus the manifest (the only change to
a vendored file); `git diff upstream main -- Service.qml NotificationLogic.js components` is empty.
Checked: `omarchy plugin validate`, `tools/check-upstream` exit 0, `test/tools-test.sh` (47 checks,
9 deliberate breaks caught), `test/logic-test.js` (35 checks). **Step 6, the live run, passed on 2026-10-30** (user-reported): installed with `omarchy plugin add <url>
--enable --yes` from the pushed repo, and every item of `docs/runbooks/live-checklist.md` in the fork repo
passed, including the disable-and-restore cycle. P0 is complete. The repo is public at
`github.com/TRemigi/omarchy-annihilation-notifications`.

The original steps:

1. Ask the user for the GitHub owner and whether the repo is public; create the local
   repo as a sibling directory first (`~/dev/omarchy-annihilation-notifications`),
   nothing pushed.
2. `git init`; commit the pristine upstream files to an `upstream` branch (copy from
   `/usr/share/omarchy/shell/plugins/notifications/`), tag `upstream/4.0.4`.
3. `main`: merge `upstream`, then change only the manifest (`id`, `name`, `version`,
   `author`, `description`, `omarchy.clonedFrom`), add `LICENSE`, `NOTICE`, `README.md`,
   `CONTRACT.md`, `AGENTS.md`, a first `UPSTREAM`.
4. `omarchy plugin validate .`; qmllint against the installed tree (method in this
   repo's AGENTS.md) and record the baseline noise.
5. Node tests that run the real `NotificationLogic.js` (it is pure and already exports
   for node).
6. The user installs it (`omarchy plugin add <path-or-url> --enable --yes`, a local
   path may need `git clone` first) and runs the live checklist, **including the
   disable-and-restore cycle**, before anything else is built. If the clone does not
   behave as in the verified facts, stop and revise this plan.

## Phase 2: designed in slices

Each slice is gated on the theme (stock behaviour otherwise), is judged live by the user before the next, and
lives on a `p2/...` branch until then. Budget: at most a handful of cards on screen, no per-frame offscreen layer
per card beyond one small shader, nothing that repaints when nothing is changing. The agent cannot see any of it
live, so each slice has offscreen tests, a shader rendered through the harness and composed over a backdrop, and
then goes to the user.

The look was chosen on 2026-10-30 from four mock-ups (`docs/design/`): **a blend of A (Refraction) as the base,
B's (Field note) typographic header, and C's (Growth) spores**, with the full C direction kept as a follow-up
experiment. A is toned down in saturation, and its rim ignites bright at arrival and cools over about a second, so
the arrival ring visibly becomes the card.

1. **Motion** (done, released as 0.2.0, all of live-checklist section D confirmed by the user; the first version
   read as "the same" and was slowed and softened, with a `motion_slowdown` setting to exaggerate it).
2. **The look** (done, released as 0.3.0). The iridescent rim with its prism spill inside and faint halo outside
   (one small shader per card), igniting at arrival; the Cinzel small-caps caption (app name, time) above the
   title; Jost for the text, with a faint glow on the title; the app icon in a ring; palettes per urgency (teal to
   violet normally, amber to pink for critical, moss for low).
3. **Countdown.** (Done, released as 0.3.0.) A line of light along the
   bottom edge that drains, ending in a spark; frozen while hovering; none for critical toasts.
4. **Spores.** The exit dissolves into a few spores, and a faint drift above a card.
5. **Switch and accents.** A setting to turn the new look and the motion off, and any per-app accents.
6. **Follow-up experiment: Growth.** Try the rest of C on a branch: the organic outline, the lichen strip, veins
   reaching out from the corners, the wavering countdown. Judge it against the blend; the mock-up's wavy outline
   and ragged strip read as glitches, so this needs more design before it is worth building.

## Phase 3 sketch

- **Card-fitted arrival glow.** The fork publishes the live card rectangles (a small
  file next to the popup files, or an IPC query). The shimmer plugin uses them when
  present and falls back to its corner anchor when absent. This removes the current
  guess about card height.
- Automatic fallback and the watchdog (above).
- Scheduled upstream-drift workflow (above).
- Possibly move the sound and missed-count logic into the fork if that proves simpler
  than watching files; only if it does not reduce what works on stock.

## Risks

- **Unsandboxed code in the shell process.** A bug in the fork can crash or freeze the
  shell; this is true of every plugin and the README must say so.
- **No daemon after a bad update** (fact 7): mitigated by hooks, watchdog, and
  fallback tooling; the hooks do not cover someone who has not installed this repo's
  extras.
- **Omarchy's internals are not a stable API.** `qs.Commons`, `qs.Ui`, the registry
  and the bar indicator can change in any release. Expect to merge on most updates.
- **State-file format** (`~/.local/state/omarchy/notifications/`) is an internal format
  that this theme already depends on, with or without the fork.
- **A user on a different Omarchy version than the fork's baseline** gets a fork whose
  vendored files do not match what they have. The hash check and the hold marker handle
  it; `docs/releases.md` and the `upstream/*` tags say which versions are known good.
- **Maintenance cost** is the whole price of this item: every Omarchy release is a
  merge. If that stops being worth it, the exit is `omarchy plugin remove` and archiving
  the repo; nothing in this theme depends on it.

## Open questions for the user

- ~~Public or private?~~ Answered: public, owner TRemigi.
- Theme gating: behave as stock off this theme (recommended), or only ever active
  when the theme is (needs the hook swap, rejected above)?
- Track only packaged Omarchy releases (recommended), or also the `dev`/`edge` channels
  (`omarchy-version-channel`)? The second means a merge on every upstream change.
- Is automatic fallback acceptable as the default, or should the default be "tell me"?

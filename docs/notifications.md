# Notifications: plan and status

Working document for making notifications a good experience in this theme.
It is meant to survive across sessions: **update the Status section as you
work, and commit it with the code.** `AGENTS.md` has the project-wide rules and
gotchas; this file is only about notifications.

## Status

| # | Item | State |
|---|------|-------|
| 0 | Notification feed (plugin learns when a toast arrives) | **built; works live** (user confirmed with item 1) |
| 1 | Arrival glow (light spreads from the toast corner) | **built; user: "looks great"** |
| 2 | Sound (synthesized, opt-in) | **built, not heard** (the agent cannot hear) |
| 4 | Missed notifications on the bar prism | **built, not seen live** |
| 6 | Themed fork of the notification daemon | **follow-up, not planned yet** |

Numbers match the numbered list in the conversation that produced this plan.
3 and 5 were offered and not chosen; they are in "Not chosen" below. Do 0 first,
then 1, 2, 4 in any order.

## Constraints (verified by reading `/usr/share/omarchy/shell`, 2026-10-30)

- Toasts are drawn by the first-party `omarchy.notifications` service
  (`plugins/notifications/Service.qml`, `components/NotificationCard.qml`). It is
  one full-screen, click-through `PanelWindow` per output (namespace
  `omarchy-notifications`, `WlrLayer.Overlay`) with a `mask` over the card
  column, top-right. Card layout, per-card entry/exit animation and text are
  inside it. We cannot restyle a card, and a plugin cannot add to one.
- Only one process can own the D-Bus notification name (`NotificationServer`), so
  a plugin cannot be a second daemon. Never edit `/usr/share/omarchy`.
- Layer rules act on the whole surface, which never resizes, so they cannot
  animate individual cards.
- What the theme already controls: the `[notifications]` tokens in `shell.toml`
  (background, text, the active-border gradient, countdown colour) and the blur
  layer rule in `extras/hypr/annihilation.lua`.
- Card width is `Style.space(380)`; height depends on the text (1 to 3 body
  lines), so a plugin cannot know a card's rectangle exactly. Placement comes from
  `NotificationLogic.popupPlacement(barPosition, barClearance, gapsOut)`.
- Our window glow is `WlrLayer.Top`, so it draws **under** the toast overlay.
  That is what makes item 1 possible.

## Item 0: the notification feed

**Built:** `NotificationFeed.qml` (owned by `Service.qml`, exposed as
`service.notifications`, signal `arrived(entry)`), logic tests in
`extras/dev/notification-feed-test.js` (29 checks, 8 deliberate breaks each
caught), and `shimmer status` reports `notificationsWatching`,
`notificationArrivals` and `notificationsRecent`. The exact `inotifywait` command
was run against a scratch directory here: it prints the name of each new file at
the top level and ignores `history/`. **Not yet seen against the real service.**
First live check for the user: `notify-send "test" "body"` and then
`omarchy-shell shimmer status` should show `notificationsWatching: true` and an
arrival with that summary. If `notificationsWatching` is false, `inotifywait` is
failing to start; if arrivals stay at 0 with it true, check the file names in
`~/.local/state/omarchy/notifications/` (the watcher only reads
`<timestamp>-<id>.json`) and that the toast's timestamp is fresh (5 s).
Still open: nothing subscribes to `arrived` yet, so the feed does nothing visible.

Everything else hangs off this. The service persists each live toast as one
compact JSON file in `~/.local/state/omarchy/notifications/` named
`<timestamp>-<originalId>.json`, written when the toast appears (`printf > file`),
rewritten in place when the sender updates the notification, and moved into
`history/` when it expires, is dismissed or is acted on. DND-silenced
notifications skip the popup directory and are written straight into `history/`
(unless ephemeral: the `transient` hint, `notify-send`, `omarchy-action`).

Fields: `id, originalId, app, appIcon, summary, body, image, glyph, execArgv,
urgency, expireTimeout, timestamp` (`urgency`: 0 low, 1 normal, 2 critical).

Design:
- A `Process` running `inotifywait -m -e close_write --format %f <dir>` (the shell
  itself uses `inotifywait`; `/usr/bin/inotifywait` is present), watching the top
  level only, not `history/` (add `-e moved_to` on a second watch of `history/` for
  item 4). Read the named file with a one-shot `cat` `Process` or a `FileView`
  (`onLoaded: x(text())`, see AGENTS.md).
- An **arrival** is a file name not seen before. A rewrite of a known name is an
  update, not an arrival, so it must not replay the effects. Keep a small
  seen-set trimmed by age.
- Ignore files older than a few seconds at startup (the service restores live
  popups after a shell restart, and a restart must not replay a burst of sound).
- Emit one signal from `Service.qml`, e.g. `notificationArrived(entry)`, and let
  items 1 and 2 subscribe. Gate on `theme.name == "annihilation"` like every other
  extra, and stop the watcher when the theme is not active.
- Expose the last few arrivals in `omarchy-shell shimmer status`.
- Unverified: that `inotifywait` sees the `printf >` close, that the file is
  complete when `close_write` fires (it should be, as the write is one `printf`),
  and the exact restart behaviour above. Test with `omarchy-notification-send` /
  `notify-send` first.

## Item 1: arrival glow

**Built:** `ArrivalGlow.qml` (one layer per screen, namespace `annihilation-arrival`,
`WlrLayer.Top`, click-through, shown only while an arrival is running),
`shaders/arrival.frag` (+ committed `.qsb`), settings `notifyGlow` and
`notifyGlowStrength` (popup: "Glow on notifications" and "Arrival glow"), the
Hyprland layer rule extended to the new namespace (needs `hyprctl reload`), and
`omarchy-shell shimmer notify [0|1|2]` to trigger one without `notify-send`.
Tests: `extras/dev/arrival-glow-test.js` (26 checks, 10 deliberate breaks each
caught). The shader was rendered through `extras/dev/shader-harness.c` (it now
takes `EV0..EV2`, `ORIGIN`, `BOX`, `REACH`, `STRENGTH`) and judged from
filmstrips over a dark backdrop with a stand-in card.

What the design is, and what it took to get there (so it is not re-derived):
- A **ring** leaves the source and travels out, widening and dimming, plus a slower
  **halo**. Duration 3.2 s low, 4.2 s normal, 6 s critical; strength 0.6 / 1 / 1.3;
  `omarchy-action` toasts 0.7 and a burst (within 400 ms of the last) 0.6; at most
  three at once. Colour: normal teal to blue, critical amber to pink, low moss to
  teal (across the ring's width only, a narrow slice of the spectrum).
- First version used the card's own 380x68 outline as the source. The ring stayed
  a big rounded rectangle (a picture frame) and a flat fill sat between card and
  ring. Blending box distance into circle distance made a shield-shaped kink at the
  lower left. What worked: a source box **narrower than the card** (100x30 half-size,
  `sourceBox`), pure rounded-box distance, so the ring rounds off soon; and the halo
  cut to sigma 0.22 reach at half the amplitude. Ring 0.30, halo 0.15.
- Measured on the real shader at 1880x1190 (border shaved): largest step between
  neighbouring pixels 3/255 (0.012), peak channel 0.45 for a critical arrival and
  0.42 for three stacked, never near white. Cost is negligible (renders at half
  scale, only while an arrival runs).
- Known: the layer is above the bar, so the glow can lighten the bar's right end;
  the origin assumes a 380 px card at `Style.gapsOut` from the corner and the bar's
  reserved area, so it is a few pixels off for a tall card; `renderScale` is 0.5.
- Live: the user ran it and said it looks great. They needed `omarchy restart shell`
  (not only `hyprctl reload` and `rescanPlugins`) to pick up the new file; see the
  AGENTS.md gotcha. Every item that adds a file needs the same instruction.
- (Superseded) **Look at it live first.** `omarchy-shell shimmer notify 1` (then 2, 0). If it is
  too strong or too weak the slider is the quick test; defaults live in the shader
  (`0.30` ring, `0.15` halo) and `amplitudeFor`.

Original brief for this item, kept for reference:

When a toast arrives, a slow ring of refracted light spreads from the top-right
corner (where toasts land) and fades over a few seconds. Colour by urgency: teal
`#61A0A8` normal, amber `#DB930D` critical, moss `#7A7653` low. Design rules from
AGENTS.md apply: edges and halos, never a saturated fill; slow and low-alpha; a
soft falloff with no hard colour edges; radially symmetric (anything borrowed from
the fans reads as a beam).

Decisions and reasons:
- **Anchor to the corner, not to the card.** Card height is unknown (see
  Constraints). Fitting a halo to a guessed rectangle will look wrong by a few
  pixels each time, while a corner-anchored wash cannot. If a card-fitted version
  is wanted later, measure first (a live screenshot) before adding an estimate.
- Draw it in the **window glow layer** (`WindowGlow.qml`, `Top`, additive,
  click-through), not the wallpaper layer, which is hidden behind windows. The
  toast overlay is above it, so the glow lights the area around the card.
- Probably a small separate shader (`shaders/arrival.frag`, plus the committed
  `.qsb`) or a uniform block added to `windowglow.frag`. Prefer a separate item so
  the window-glow shader and its tests stay byte-identical when no toast is live
  (the same discipline the cursor mode follows).
- Multiple toasts: queue or sum with a cap; rapid bursts must not stack to a
  flash. Respect fullscreen (hidden under fullscreen, like the glow).
- Reach in pixels at the user's real resolution (about 1880x1190 logical), not in
  a scaled preview. AGENTS.md records how that bit the window glow.
- Setting: `notifyGlow` (bool, default on) and an intensity, in the popup next to
  the other sliders.

Verification: render with `extras/dev/shader-harness.c` over a synthetic desktop,
look at a filmstrip of the ring over time, and scan with `extras/dev/edge-scan.py`
for colour steps. Only the user can judge it live.

## Item 2: sound

**Built:** three synthesized tones in `sounds/` (`arrive.ogg` G4 with its fifth and a
faint octave shimmer, `low.ogg` C4 alone and quieter, `urgent.ogg` G3 then C#4, a
tritone), made by `extras/dev/make-sounds.py` (stdlib and ffmpeg; rerun it to
retune). Peaks are -8.8, -14.9 and -8.9 dBFS; the volume setting scales down from
there. Checked by level and spectrogram only: **nobody has heard them.** Playback
is `Service.playSound` (`pw-play --volume`, falling back to `paplay`, errors
ignored); the gating is `Service.soundFor`, tested in
`extras/dev/notify-sound-test.js` (16 checks, 8 deliberate breaks caught).
Settings `notifySound` (default **off**) and `notifySoundVolume` (0.05 to 1, 0.5),
in the popup as "Sound on notifications" and "Sound volume".
Rules as built: `omarchy-action` toasts are silent unless critical; at most one a
second; none under the screensaver; the feed is only live on this theme.
To audition: `omarchy-shell shimmer sound arrive|low|urgent` plays one at the
current volume whether or not sound is on; `omarchy-shell shimmer notify 1` plays
the arrival path (only if sound is on). Needs `omarchy restart shell` for the new
IPC function and settings.
If the tones are wrong the knobs are in `make-sounds.py`: pitch, `decay`, `attack`,
`detune` (the beating), the echo line and the target levels.
Wishes not done: a per-app choice, and a quiet-hours setting.

Original brief for this item, kept for reference:

A synthesized tone, so there is no licensing question. Slow attack (about 120 ms),
long decay, slightly detuned partials that beat gently, like glass or refracted
light. Three variants by urgency: normal, low (quieter and lower), critical (a
lower two-note figure, still not an alarm). Generate with `ffmpeg` (present) from
`extras/dev/` script, commit the small output files under the plugin
(`sounds/*.wav` or `.ogg`) plus the script that made them, and play with `pw-play`
(present). Check the result by spectrogram and level, because the agent cannot
hear it.

Decisions:
- **Opt-in** (`notifySound`, default off), with a volume setting.
- **Skip `omarchy-action` toasts.** The user's history is all of those
  (screenshots and recordings): they just pressed the key, so a sound is noise.
  Play for other apps and for critical urgency. Setting to include them is cheap.
- DND is free: silenced notifications never produce a popup file.
- Rate limit: at most one sound per second or so, and none while the screensaver
  is up.
- Never block: spawn `pw-play` in a `Process`, ignore failure.

## Item 4: missed notifications on the prism

**Built, not seen live.** Needs `omarchy restart shell` (new file).
- `MissedTracker.qml` (owned by `Service.qml`) watches `history/` with
  `inotifywait -e close_write -e moved_to` (event line format checked against real
  inotify here) and judges each file. **The rule differs from the first sketch below**:
  "newer than lastSeen" would have counted toasts the user dismissed or clicked, since
  those also land in `history/`. The service moves a toast there with `mv` (moved_to)
  and writes a DND-silenced one directly (close_write), and how long a toast was on
  screen tells what happened: *silenced* = missed; *expired* (on screen for its whole
  lifetime: 5 s low, 8 s normal or the requested timeout, 30 s at most, minus 0.5 s
  grace) = missed; dismissed or clicked earlier = not missed; critical toasts only
  leave by dismissal = not missed; `omarchy-action` = never missed. A toast that sat
  on screen while the user read it still counts as expired; that cannot be known.
  Lifetimes mirror `Service.durationFor` in the first-party notification plugin: if
  Omarchy changes those numbers, change `lifetimeFor`.
- The list (newest first, at most ten, nothing older than a week) is saved to
  `~/.local/state/annihilation-theme/missed.json`, which is also how it reaches the
  widget and popup (the widget reads files on purpose; it never talks to the service).
- Bar prism (`BarWidget.qml`): one to three motes on the right edge, in the glyph's own
  colour cycle on its existing 1 s step (no running animation), a stronger fill, and
  the tooltip says "Area X · N unseen".
- Popup (`Panel.qml`): a "WHILE YOU WERE AWAY" section with the newest five (summary,
  then app, age and "silenced"). Opening the popup snapshots them, then calls
  `omarchy-shell shimmer seen`, which empties the file; the snapshot stays until the
  popup closes.
- `shimmer status` has `missedWatching` and `missed`. Tests:
  `extras/dev/missed-tracker-test.js` (37 checks, 13 deliberate breaks caught) and
  `extras/dev/panel-missed-test.js` (9 checks).
- **Testing the silenced path: do not use a bare `notify-send`.** With DND on the
  service drops any notification whose app name is `notify-send` or `omarchy-action`
  (`NotificationLogic.isEphemeralApp`): no toast, and nothing written to history, so
  nothing for the tracker to see. (Critical `notify-send` bypasses DND and shows.) Give
  the test its own app name: `notify-send -a Signal "test" "body"`. The user hit this
  on the first live try, because the test command given to them was a bare `notify-send`.
- Known limits: nothing is counted while the shell is not running (inotify only sees
  new events); a restored-after-restart toast leaving later counts as expired; a
  notification replaced by its sender is judged as its own file; the popup shows at
  most five.

First sketch, kept for reference:

A toast lasts 8 seconds. Make what was missed visible on the bar prism
(`BarWidget.qml`) until the user looks: a faint tint, or a few motes orbiting the
prism, with a count in the popup (`Panel.qml`). Cleared when the popup is opened.

Design:
- Source: `history/` (kept to the newest 10 by the service, so this cannot be an
  unbounded count). **Unread** = history entries newer than a persisted `lastSeen`
  timestamp. Include DND-silenced ones (they are exactly what was missed).
  Exclude `omarchy-action` by default, for the reason in item 2.
- Watch `history/` for `moved_to`/`close_write` (silenced ones are written
  directly there).
- `lastSeen` is persisted plugin state (as `passageIndex` is), set when the popup
  opens.
- Follow the AGENTS.md rule for the bar: no running animation for something
  slow; use the existing 1 s `Timer` approach. Motes must be subtle.
- The popup lists the unread entries as short field notes (app, summary, time).
  Do not add copyrighted text; any flavour text is original, in the manner of
  `journal.txt`.

## Item 6: themed fork of the daemon (follow-up)

The only route to real per-card motion: cards that bloom in like windows, a border
that traces the countdown, an exit that dissolves into spores, per-app glyphs.
Not started, and not recommended until 0, 1, 2 and 4 have been lived with.

What it would cost, so a later session can decide:
- Forking about 1,700 lines (`Service.qml` 1063, `NotificationLogic.js` 479,
  `NotificationCard.qml` 196) and keeping the `notifications` IPC target working
  (other Omarchy tools call it), plus DND, history, replay and restore.
- It drifts from upstream with each Omarchy update; someone has to re-merge.
- It must be active only on this theme. The upstream service has `keepLoaded:
  true` and owns the D-Bus name, so swapping needs disable/enable through shell
  IPC with no window where both run. Needs a careful hand-over design before any
  code.
- `omarchy plugin validate` and the dormant-elsewhere rule still apply.

First step if picked up: ask the user whether it is wanted, then write a short
design note here (hand-over, IPC surface, what stays identical) before coding.

## Not chosen (kept so they are not re-derived)

- **3. DND as "the air stills".** Ease `layerSpeed` to a crawl and dim the window
  glow while DND is on. Almost free; read `dnd` from `notifications.json` or the
  `omarchy-shell notifications isDnd` IPC. Offered, not picked.
- **5. Theme-only tweaks.** Choose the critical and low-urgency colours on purpose
  (`Color.urgent`, the dim colour) and slow `layersIn`/`layersOut` for
  `omarchy-notifications` to match the windows' bloom. Minor.

## Open questions for the user

The user has not yet answered these; the defaults above are my assumptions.
- Is the sound default (opt-in, skipping `omarchy-action`) right?
- Do chat and other apps send toasts that matter, or is it mostly the screenshot
  and recording flow? This decides how much 2 and 4 will ever do.
- Is the arrival glow's corner anchoring acceptable, or should it hug the card
  (needs a measurement pass first)?

## Verification (this sandbox has no compositor)

Same rules as AGENTS.md: syntax and QML lint, shader harness, node logic tests in
`extras/dev/` (add `notification-feed-test.js` for the seen-set, update and
startup rules, and break each check on purpose to prove it fails), and the
installer in a fake `HOME`. Live checks for the user: `notify-send -a Signal "test" "body"`
(the `-a` matters: a bare `notify-send` is ephemeral and is dropped under DND),
`-u critical`, `-u low`, and
`omarchy-shell shimmer status`. Remember the plugin dir is symlinked, so run
`omarchy-shell shell rescanPlugins` after edits.

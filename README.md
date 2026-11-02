# omarchy-annihilation-theme

An [Omarchy](https://omarchy.org/) theme based on the
[Swamp Dark](https://tinted-theming.github.io/tinted-gallery/#base16-swamp-dark)
base16 palette, themed after *Annihilation*. The teal accent is the Shimmer
cutting through the brown marsh: muted browns and moss, with iridescence only
at the edges, and every motion slow enough that you only notice it afterwards.

## Install

    omarchy theme install https://github.com/TRemigi/omarchy-annihilation-theme
    omarchy theme set annihilation

or copy this directory to `~/.config/omarchy/themes/annihilation` and run
`omarchy theme set annihilation`.

That gets you the palette, backgrounds, a hand-tuned `shell.toml` (translucent
bar, gradient borders on popups, notifications, menus and the lock screen), a
`btop.theme`, and the recolored disk-unlock wordmark. Hyprland borders pick up
the Shimmer gradient from `colors.toml`.

## Extras

Omarchy drops `*.lua`, shell plugins and hooks from themes installed out of a git repo, so the live parts
ship separately, in two places.

**The shell plugin** (the Shimmer layer, light on window edges, the screensaver, the bar glyph and the
notification marks) is its own repo,
[omarchy-area-x](https://github.com/TRemigi/omarchy-area-x), installed and updated with Omarchy's own
plugin commands. Its README has what it does, its settings and its commands.

    omarchy plugin add https://github.com/TRemigi/omarchy-area-x.git --enable
    omarchy restart shell

    omarchy plugin update annihilation.area-x      # to update; then omarchy restart shell

**The Hyprland tweaks and the hooks** are in this repo's `extras/`. Run the installer from the copy Omarchy
keeps up to date (`~/.config/omarchy/themes/annihilation`, which "Extra Themes" in the update menu pulls), so
the symlinks it makes always point at current files:

    ~/.config/omarchy/themes/annihilation/extras/install link

| Part | What it does |
| --- | --- |
| Hyprland | A border gradient that slowly turns, a faint teal shadow on the focused window, blur on shell surfaces, 6% dimming of inactive windows, slower open/close and workspace motion. |
| Screensaver switch | While this theme is active, turns off Omarchy's own screensaver so the plugin's takes its place (the plugin stands down whenever Omarchy's is on, so without this you get the stock one). It is turned back on for any other theme. |

`extras/install link` also adds the plugin if it is missing (and removes the dangling symlink an older version of
this installer made, under the plugin's first id, `annihilation.shimmer`), installs the theme-set hook, and installs two hooks for the optional notification fork
(below), which do nothing unless that is installed.

Everything is tied to the theme: switch to another theme and the extras go dormant, and Omarchy's own
screensaver is restored if this theme turned it off.

    extras/install status     # what is installed, and how the plugin is installed
    extras/install unlink     # remove the Lua and the hooks, restore the stock screensaver

If you had the plugin from an earlier version, your `shell.json` still names it `annihilation.shimmer`, which the
installer will tell you; the bar glyph and your settings carry over once you rename that id (`status` shows the
command):

    sed -i 's/"annihilation.shimmer"/"annihilation.area-x"/g' ~/.config/omarchy/shell.json

`unlink` leaves the plugin installed (it is its own project and works without these extras); remove it with
`omarchy plugin remove annihilation.area-x`.


### Notification fork (optional)

The arrival of a toast (a front of light that leaves its icon, crosses the card and goes on as a ring that hugs it) lives in the fork, not in the plugin: the plugin used to draw a ring from the corner of the screen, which could not know where the card was. Without the fork there is no arrival light, and the stock daemon's toasts appear as usual.

The plugin's notification features (the quiet tone, the missed marks on the bar) work with Omarchy's stock daemon. Separately, there is a themed
notification *daemon*: [omarchy-annihilation-notifications](https://github.com/TRemigi/omarchy-annihilation-notifications),
a fork of Omarchy's own notifications plugin, installed as a registered clone of it, so that the bar's
Do Not Disturb button, the key bindings and `omarchy-notification-send` keep working and **disabling it
brings the stock daemon back**. It is its own project, with its own README, features and releases;
this section only covers installing and guarding it from here.

> Plugins run as unsandboxed code inside `omarchy-shell`, and this one *is* your notification daemon.
> While it is enabled it replaces the stock daemon on every theme, and if an Omarchy update breaks it
> you would have no notifications. That is what the guard below is for.

    extras/install notifications add        # install it with `omarchy plugin add`; enables it only if it is in step
    extras/install notifications status     # installed? enabled? in step with your Omarchy? who owns the D-Bus name?
    extras/install notifications update     # pull the latest; come back from an automatic fallback
    extras/install notifications fallback   # use the stock daemon now (the fork stays installed)
    extras/install notifications enable     # switch it back on (refuses while it is out of step; --force overrides)
    extras/install notifications remove     # uninstall it; stock returns
    extras/install notifications auto off   # only tell me; do not fall back by yourself (default: on)

After `add` or `enable`, run `omarchy restart shell`.

**The guard.** The fork vendors a copy of Omarchy's plugin, so an Omarchy update can leave it behind. The
fork's own `tools/check-upstream` says whether your installed Omarchy still matches what the fork was last
merged against. `extras/install link` installs two hooks, one after `omarchy-update` and one at login (which
also covers plain `pacman` updates), that run that check, and if the fork is enabled and Omarchy has changed
a file it depends on, switch to the stock daemon and tell you (a notification once stock is back, and on the
terminal). Not being able to run the check is not treated as a reason to switch. After a fallback,
`extras/install notifications update` brings the fork back once it has caught up. The log is
`~/.local/state/annihilation-theme/notifications-fork.log`, and the reason for a hold is in
`~/.local/state/annihilation-theme/notifications-fork-held`.

If you are ever left with no notifications and the commands do not work, the manual fix is in the fork's
[fallback runbook](https://github.com/TRemigi/omarchy-annihilation-notifications/blob/main/docs/runbooks/fallback.md):
`omarchy plugin disable annihilation.notifications`, or edit `~/.config/omarchy/shell.json` by hand. Do not
just delete the plugin folder.

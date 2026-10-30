#!/bin/bash

# Omarchy post-boot hook: if the optional themed notification daemon is enabled, check that the installed
# Omarchy still matches what it was merged against, and fall back to the stock daemon if not (see
# extras/notifications-fork and docs/notifications-fork.md). Linked into
# ~/.config/omarchy/hooks/post-boot.d/ by extras/install, never copied, so the repo is resolved from this
# file's real location. Does nothing unless the fork is installed and enabled, and always exits 0.

REPO=$(dirname "$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")")
"$REPO/extras/notifications-fork" guard post-boot
exit 0

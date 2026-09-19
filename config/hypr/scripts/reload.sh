#!/usr/bin/env bash
# ALT+SHIFT+R — reload the compositor config AND bring the bar back.
#
# `hyprctl reload` re-reads hyprland.conf but does NOT re-run exec-once: those
# fire once, at compositor startup. So a waybar that was killed by hand (or
# that crashed) stays dead through a reload — which is precisely the moment you
# want it back. Restart it here instead.

export PATH="/opt/hypr/bin:$PATH" # hyprctl lives in the prefix

hyprctl reload

# restart, not just start: this also picks up style.css / module edits
# made since login
pkill -x waybar
setsid -f /opt/waybar/bin/waybar >/dev/null 2>&1

command -v notify-send >/dev/null && notify-send "Hyprland" "Config reloaded"

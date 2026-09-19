#!/usr/bin/env bash
# Shared fuzzel dmenu wrapper. Replaces the old wofi-menu.sh.
#
# The sway focus-watcher that version needed is GONE: fuzzel has
# `exit-on-keyboard-focus-loss=yes` (set in ~/.config/fuzzel/fuzzel.ini),
# so clicking another window closes it natively. That deleted ~15 lines
# of swaymsg/jq plumbing and the `focus_follows_mouse no` dependency.
#
# --log-level=error silences fuzzel's normal info: chatter.

# toggle: pressing the same keybind again closes the open menu
if pgrep -x fuzzel >/dev/null; then
	pkill -x fuzzel
	exit 1
fi

exec fuzzel --dmenu --log-level=error "$@"

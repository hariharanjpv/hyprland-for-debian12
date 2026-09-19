#!/usr/bin/env bash
# select | random   — picker over $WALL_DIR, applied with swaybg
# Hyprland has no built-in wallpaper setter; swaybg is a plain layer-shell
# client and works fine here (hyprpaper would be the native option once built).
WALL_DIR="${WALL_DIR:-/opt/wallpapers}"
MENU="$HOME/.config/hypr/scripts/menu.sh"
LINK="$HOME/.config/hypr/current-wallpaper"
find_walls() { find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) "$@"; }

case "$1" in
random) PICK=$(find_walls | shuf -n1) ;;
*)
	PICK=$(find_walls -printf '%f\n' | sort | "$MENU" -p "Wallpaper ")
	[ -n "$PICK" ] && PICK="$WALL_DIR/$PICK"
	;;
esac
[ -z "$PICK" ] && exit 0

ln -sfn "$PICK" "$LINK"
pkill -x swaybg 2>/dev/null
setsid -f swaybg -i "$PICK" -m fill >/dev/null 2>&1
command -v notify-send >/dev/null && notify-send "Wallpaper" "$(basename "$PICK")"

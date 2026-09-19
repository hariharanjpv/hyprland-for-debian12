#!/usr/bin/env bash
# Lock-screen image picker (fuzzel over $WALL_DIR). "Follow wallpaper" keeps it in sync with the wallpaper picker.
WALL_DIR="${WALL_DIR:-/opt/wallpapers}"
MENU="$HOME/.config/hypr/scripts/menu.sh"
LINK="$HOME/.config/hypr/lock-image"
WALL="$HOME/.config/hypr/current-wallpaper"
notify() { command -v notify-send >/dev/null && notify-send "Lock screen" "$1"; }
CUR=$(readlink -f "$LINK" 2>/dev/null)
mark() { [ "$(readlink -f "$1")" = "$CUR" ] && echo "  ✔"; }
LIST=$(find "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort)
MENU="󰸉  Follow wallpaper$( [ "$(readlink "$LINK")" = "$WALL" ] && echo '  ✔')\n󰈈  Preview current lock screen\n"
while read -r f; do [ -n "$f" ] && MENU+="$f$(mark "$WALL_DIR/$f")\n"; done <<<"$LIST"
CHOICE=$(printf "$MENU" | sed '/^$/d' | "$MENU" -p "Lock screen ")
[ -z "$CHOICE" ] && exit 0
case "$CHOICE" in
  *"Follow wallpaper"*) ln -sfn "$WALL" "$LINK"; notify "Now follows the wallpaper" ;;
  *"Preview"*)          exec /opt/hypr/bin/hyprlock --config "$HOME/.config/hypr/hyprlock.conf" ;;
  *) PICK="$WALL_DIR/$(sed 's/  ✔$//' <<<"$CHOICE")"; [ -f "$PICK" ] || exit 1
     ln -sfn "$PICK" "$LINK"; notify "$(basename "$PICK")" ;;
esac

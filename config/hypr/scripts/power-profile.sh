#!/usr/bin/env bash
MENU="$HOME/.config/hypr/scripts/menu.sh"
CUR=$(powerprofilesctl get 2>/dev/null)
mark() { [ "$1" = "$CUR" ] && echo "  (current)"; }
CHOICE=$(printf '󰓅  Performance%s\n󰾅  Balanced%s\n󰾆  Power saver%s\n' \
	"$(mark performance)" "$(mark balanced)" "$(mark power-saver)" | "$MENU" -p "Power profile ")
case "$CHOICE" in
*Performance*) P=performance ;;
*Balanced*) P=balanced ;;
*"Power saver"*) P=power-saver ;;
*) exit 0 ;;
esac
powerprofilesctl set "$P" && command -v notify-send >/dev/null && notify-send "Power profile" "$P"
pkill -SIGRTMIN+8 waybar 2>/dev/null || true

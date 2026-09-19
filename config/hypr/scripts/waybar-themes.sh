#!/usr/bin/env bash
# Kernel-Fault waybar theme switcher (fuzzel).
THEME_DIR="$HOME/.config/waybar/themes"
WAYBAR_DIR="$HOME/.config/waybar"

notify() { command -v notify-send >/dev/null && notify-send "Waybar Theme" "$1"; echo "$1"; }

THEMES=$(ls -1 "$THEME_DIR")
if command -v fuzzel >/dev/null; then
    THEME=$(echo "$THEMES" | "$HOME/.config/hypr/scripts/menu.sh" -p "Waybar theme ")
else
    THEME="${1:-}"   # fallback: pass the theme name as an argument
fi

[ -z "$THEME" ] && exit 0
if [[ ! -d "$THEME_DIR/$THEME" ]]; then
    notify "Theme '$THEME' not found"; exit 1
fi

for f in colors.css style.css config.jsonc; do
    if [ -e "$THEME_DIR/$THEME/$f" ]; then
        ln -sf "$THEME_DIR/$THEME/$f" "$WAYBAR_DIR/$f"
    fi
done

pkill -x waybar
sleep 0.2
setsid -f /opt/waybar/bin/waybar >/dev/null 2>&1

notify "Switched to $THEME"

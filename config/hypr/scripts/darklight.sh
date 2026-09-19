#!/usr/bin/env bash
# Toggle dark/light for GTK3 (theme name), GTK4/libadwaita & browsers (portal
# color-scheme), and future apps (settings.ini)
CUR=$(gsettings get org.gnome.desktop.interface color-scheme)
if [[ "$CUR" == *dark* ]]; then MODE=light; SCHEME=default; THEME=Adwaita; PREFER=0
else MODE=dark; SCHEME=prefer-dark; THEME=Adwaita-dark; PREFER=1; fi
gsettings set org.gnome.desktop.interface color-scheme "$SCHEME"
gsettings set org.gnome.desktop.interface gtk-theme "$THEME"
for v in gtk-3.0 gtk-4.0; do
	mkdir -p ~/.config/$v
	printf '[Settings]\ngtk-theme-name=%s\ngtk-application-prefer-dark-theme=%s\n' "$THEME" "$PREFER" > ~/.config/$v/settings.ini
done
pkill -RTMIN+9 -x waybar 2>/dev/null || true
command -v notify-send >/dev/null && notify-send "Theme" "Switched to $MODE mode"

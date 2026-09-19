#!/usr/bin/env bash
# Install the reference configs into ~/.config and ~/.local/bin.
# Existing files are backed up with a .bak-<timestamp> suffix, never clobbered.
set -euo pipefail
cd "$(dirname "$0")"

TS=$(date +%Y%m%d-%H%M%S)
backup() { [ -e "$1" ] && { cp -a "$1" "$1.bak-$TS"; echo "  backed up $1 -> $1.bak-$TS"; }; return 0; }

install -d ~/.config/hypr/scripts ~/.config/fuzzel ~/.local/bin

for f in hyprland.conf hyprlock.conf; do
	backup ~/.config/hypr/$f
	install -m644 "config/hypr/$f" ~/.config/hypr/$f
done
install -m755 config/hypr/scripts/*.sh ~/.config/hypr/scripts/
backup ~/.config/fuzzel/fuzzel.ini
install -m644 config/fuzzel/fuzzel.ini ~/.config/fuzzel/fuzzel.ini
install -m755 config/bin/hypr config/bin/hypr-menu ~/.local/bin/

echo
echo "Installed. Notes:"
echo "  * ~/.local/bin must be on PATH (Debian's ~/.profile adds it if it exists)."
echo "  * Wallpapers: scripts default to \$WALL_DIR, or /opt/wallpapers if unset."
echo "  * The bar is started from \$HOME/.config/hypr/hyprland.conf via an"
echo "    absolute path to /opt/waybar/bin/waybar — edit if you used a"
echo "    different prefix, or comment the exec-once out for no bar."

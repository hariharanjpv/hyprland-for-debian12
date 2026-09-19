#!/usr/bin/env bash
# Register Hyprland with your display manager (GDM, SDDM, LightDM, greetd...).
#
# Do NOT just copy /opt/hypr/share/wayland-sessions/hyprland.desktop — its
# Exec is /opt/hypr/bin/start-hyprland, which execs "Hyprland" by name. A
# display manager's PATH does not include /opt/hypr/bin, so the session exits
# immediately and you land back on the login screen. See config/session/.
set -euo pipefail
cd "$(dirname "$0")"

sudo install -m755 config/session/hyprland-session /usr/local/bin/hyprland-session
sudo install -m644 config/session/hyprland.desktop /usr/share/wayland-sessions/hyprland.desktop

command -v desktop-file-validate >/dev/null \
	&& desktop-file-validate /usr/share/wayland-sessions/hyprland.desktop \
	&& echo "desktop entry validates"

echo
echo "Installed. Log out and pick 'Hyprland' at your display manager."
echo "If the session bounces back to the login screen, check:"
echo "  journalctl -b --user -n 80"
echo "  cat /usr/share/wayland-sessions/hyprland.desktop"

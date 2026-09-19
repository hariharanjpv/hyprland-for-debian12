#!/usr/bin/env bash
# Register xdg-desktop-portal-hyprland so screen sharing works.
#
# Three separate things have to line up, and xdph being built is only the first:
#
#  1. systemd must SEE the unit. It is installed to /opt/hypr/lib/systemd/user,
#     which systemd does not scan -> symlink it into ~/.config/systemd/user.
#  2. xdg-desktop-portal must FIND hyprland.portal. Version 1.16 (bookworm)
#     only scans /usr/share/xdg-desktop-portal/portals and has no drop-in dir,
#     so a service drop-in points XDG_DESKTOP_PORTAL_DIR at a user directory.
#     That variable REPLACES the search path rather than adding to it, so the
#     system portals must be symlinked in as well or file-picker dialogs break.
#  3. xdph must know which picker to use -> ~/.config/hypr/xdph.conf.
set -euo pipefail
cd "$(dirname "$0")"

PREFIX="${PREFIX:-/opt/hypr}"
[ -x "$PREFIX/libexec/xdg-desktop-portal-hyprland" ] || {
	echo "xdph not built — run ./build.sh 09 first" >&2; exit 1; }

# 1. unit
install -d ~/.config/systemd/user
ln -sfn "$PREFIX/lib/systemd/user/xdg-desktop-portal-hyprland.service" \
	~/.config/systemd/user/xdg-desktop-portal-hyprland.service

# 2. portal search dir
PORTALS="$HOME/.local/share/xdg-desktop-portal/portals"
install -d "$PORTALS"
ln -sfn "$PREFIX/share/xdg-desktop-portal/portals/hyprland.portal" "$PORTALS/hyprland.portal"
# keep the system ones reachable — XDG_DESKTOP_PORTAL_DIR replaces, not appends
for f in /usr/share/xdg-desktop-portal/portals/*.portal; do
	[ -e "$f" ] && ln -sfn "$f" "$PORTALS/$(basename "$f")"
done

install -d ~/.config/systemd/user/xdg-desktop-portal.service.d
sed "s|@HOME@|$HOME|g" config/portal/hyprland-portals.conf.in \
	> ~/.config/systemd/user/xdg-desktop-portal.service.d/hyprland-portals.conf

# 3. picker config
install -d ~/.config/hypr
sed "s|@HOME@|$HOME|g" config/portal/xdph.conf.in > ~/.config/hypr/xdph.conf

systemctl --user daemon-reload
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true

echo
echo "Registered. Verify after logging into Hyprland:"
echo "  systemctl --user status xdg-desktop-portal-hyprland.service"
echo "  pgrep -af xdg-desktop-portal"
echo
echo "The service has ConditionEnvironment=WAYLAND_DISPLAY, so it only starts"
echo "inside a Wayland session — not from a TTY or over SSH."

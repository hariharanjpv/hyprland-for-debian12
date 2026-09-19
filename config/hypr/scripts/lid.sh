#!/usr/bin/env bash
# Laptop lid handling.
#
# CLOSE: if an external display is connected, disable the laptop panel.
#        Hyprland re-homes that monitor's workspaces (q/w/e/r) onto the
#        remaining display by itself.
#        If NO external display is connected, do nothing -- disabling the only
#        monitor would leave the session with nowhere to draw, and you would be
#        staring at a black screen with no way back.
#
# OPEN:  re-enable the panel and send q/w/e/r home. The workspace rules in
#        hyprland.conf only decide where a workspace is CREATED; workspaces
#        that already exist do not re-home themselves, so move them explicitly.

export PATH="/opt/hypr/bin:$PATH"
PANEL="${PANEL:-eDP-1}"
NAMED=(q w e r)

externals() {
	hyprctl -j monitors all |
		python3 -c '
import json, sys, os
panel = os.environ.get("PANEL", "eDP-1")
mons = json.load(sys.stdin)
# an external is any enabled monitor that is not the panel
print(sum(1 for m in mons if m["name"] != panel and not m.get("disabled", False)))'
}


# Waybar does not re-lay-out its layer surfaces when an output is removed or
# moved: disabling eDP-1 shifts HDMI-A-1 to 0,0, but the bar keeps its old
# x=1926 origin and ends up drawn off the right edge of the screen -- it looks
# like the bar vanished. Restarting it after any monitor change fixes the
# geometry. Cheap: the bar takes well under a second to come back.
restart_bar() {
	pkill -x waybar
	setsid -f /opt/waybar/bin/waybar >/dev/null 2>&1
}

case "${1:-}" in
close)
	n=$(externals)
	if [ "${n:-0}" -gt 0 ]; then
		hyprctl keyword monitor "$PANEL, disable"
		sleep 0.5
		restart_bar
	else
		notify-send "Lid" "No external display - keeping the panel on" 2>/dev/null
	fi
	;;
open)
	hyprctl keyword monitor "$PANEL, preferred, auto, 1"
	# give the output a moment to come back before addressing it
	for _ in 1 2 3 4 5; do
		hyprctl -j monitors | grep -q "\"$PANEL\"" && break
		sleep 0.4
	done
	for w in "${NAMED[@]}"; do
		hyprctl dispatch moveworkspacetomonitor "name:$w $PANEL" >/dev/null 2>&1
	done
	restart_bar
	;;
*)
	echo "usage: $(basename "$0") {close|open}" >&2
	exit 2
	;;
esac

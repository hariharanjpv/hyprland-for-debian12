#!/usr/bin/env bash
# Night light via wlsunset (30 KB, wlr-gamma-control — works under Hyprland).
#
# wlsunset has no runtime control interface: you configure it with flags at
# launch, so on/off is literally "is the process alive". Hence pkill + exec
# rather than any kind of IPC.
#
#   on | off | toggle | status
#
# Night light is wanted ALL the time, so sunrise/sunset are set one minute
# apart: the "day" window is 06:00-06:01 and everything else is night, i.e.
# warm. The fade duration has to be short to match, or wlsunset spends its
# life mid-transition.

LOW=4000       # night temperature (warm) -- effectively the only one used
HIGH=6500      # day temperature; the "day" window is one minute long
SUNRISE=06:00
SUNSET=06:01   # one minute after sunrise => warm for 23h59m
DURATION=60    # fade must be short, or the 1-minute window never settles

running() { pgrep -x wlsunset >/dev/null; }

start() {
	pkill -x wlsunset 2>/dev/null          # never run two at once
	setsid -f wlsunset -t "$LOW" -T "$HIGH" -S "$SUNRISE" -s "$SUNSET" -d "$DURATION" \
		>/dev/null 2>&1
}

case "${1:-toggle}" in
on)  start ;;
off) pkill -x wlsunset 2>/dev/null ;;
toggle)
	if running; then
		pkill -x wlsunset
		command -v notify-send >/dev/null && notify-send "Night light" "Off"
	else
		start
		command -v notify-send >/dev/null && notify-send "Night light" "On - ${LOW}K (always)"
	fi
	;;
status) # waybar custom module: icon reflects state
	running && echo "󰛨" || echo "󰹏"
	;;
*) echo "usage: $(basename "$0") {on|off|toggle|status}" >&2; exit 2 ;;
esac

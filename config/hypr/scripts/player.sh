#!/usr/bin/env bash
# Transport control + status for waybar's media group.
#
# JaKooLit's mpris / custom-playerctl are one widget with three hidden click
# actions. These are discrete buttons instead, so each control is its own
# clickable target with its own icon and tooltip.
#
#   status           -> streams json for the play/pause button
#   label            -> streams json for the track text
#   toggle|next|prev -> act on the active player
#
# ---------------------------------------------------------------------------
# WHY THIS IS ONE PYTHON PROCESS AND NOT A SHELL PIPELINE
#
# Waybar does not reliably reap module children, and this module writes only
# when the player state changes -- so it never hits SIGPIPE to learn the bar
# died. Two earlier shapes both leaked:
#
#   1. a pidfile that evicted the previous instance. WRONG on multi-monitor:
#      waybar runs one module instance per bar, so the second monitor's
#      instance killed the first and left that bar's widget frozen.
#
#   2. `{ playerctl ... } | python`, re-exec'd under setsid. Two faults: bash
#      waits for BOTH sides of a pipeline, so python exiting on BrokenPipeError
#      left the feed blocked inside `playerctl --follow` forever; and setsid
#      detached the script from waybar entirely, so waybar's SIGTERM went to
#      the `sh -c` and never reached it.
#
# So: python owns playerctl as a DIRECT child, kills it in `finally`, and
# treats SIGTERM as a normal exit so that finally actually runs. A 30s
# heartbeat re-writes the current payload -- the write is the only way to
# discover waybar closed the pipe when nothing else is happening.
# ---------------------------------------------------------------------------

MODE="${1:-status}"
case "$MODE" in
toggle) exec playerctl play-pause ;;
next)   exec playerctl next ;;
prev)   exec playerctl previous ;;
status | label) ;;
*) echo "usage: $(basename "$0") {status|label|toggle|next|prev}" >&2; exit 2 ;;
esac

exec python3 -u -c '
import json, selectors, signal, subprocess, sys

mode = sys.argv[1]
FMT  = "{{status}}\t{{artist}}\t{{markup_escape(title)}}\t{{playerName}}"
ICON = {"Playing": "\uf04c", "Paused": "\uf04b"}  # nerd-font pause/play
# NOTE: written as escapes, not literal glyphs -- pasting the raw characters
# through a heredoc silently stripped them and the widget rendered blank.

signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))  # so finally: runs

def render(line):
    status, artist, title, player = (line.split("\t") + [""] * 4)[:4]
    body = " - ".join(x for x in (artist, title) if x)
    return json.dumps({
        "text":    body if mode == "label" else ICON.get(status, ""),
        "class":   status.lower() or "stopped",
        "alt":     status or "Stopped",
        "tooltip": f"{player}: {body}" if body else "No media",
    })

# --follow emits only on the NEXT change, never current state, so read once up
# front or a bar started mid-song sits blank until you press something.
try:
    first = subprocess.run(["playerctl", "metadata", "--format", FMT],
                           capture_output=True, text=True, timeout=5).stdout.strip()
except Exception:
    first = ""

payload = render(first or "Stopped")
last = None

proc = subprocess.Popen(["playerctl", "--follow", "metadata", "--format", FMT],
                        stdout=subprocess.PIPE, text=True)
sel = selectors.DefaultSelector()
sel.register(proc.stdout, selectors.EVENT_READ)

try:
    print(payload, flush=True)
    last = payload
    while True:
        if not sel.select(timeout=30):
            print(payload, flush=True)   # heartbeat: the WRITE is the point
            continue
        line = proc.stdout.readline()
        if not line:                      # playerctl exited
            break
        payload = render(line.rstrip("\n"))
        if payload != last:               # playerctl re-emits on connect
            last = payload
            print(payload, flush=True)
except (BrokenPipeError, KeyboardInterrupt, SystemExit):
    pass                                  # waybar is gone
finally:
    proc.terminate()
    try:
        proc.wait(timeout=2)
    except Exception:
        proc.kill()
' "$MODE"

#!/usr/bin/env bash
# prints active keyboard layout; --switch cycles to the next one
export PATH="/opt/hypr/bin:$PATH"

if [ "$1" = "--switch" ]; then
	dev=$(hyprctl -j devices | python3 -c '
import json, sys
ks = json.load(sys.stdin)["keyboards"]
main = next((k["name"] for k in ks if k.get("main")), None)
print(main or (ks[0]["name"] if ks else ""))')
	[ -n "$dev" ] && hyprctl switchxkblayout "$dev" next >/dev/null
	exit 0
fi

hyprctl -j devices | python3 -c '
import json, sys
ks = json.load(sys.stdin)["keyboards"]
k = next((x for x in ks if x.get("main")), ks[0] if ks else None)
name = (k or {}).get("active_keymap", "us")
print(name.split(" (")[0].replace("English", "EN"))'

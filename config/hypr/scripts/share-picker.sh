#!/usr/bin/env bash
# Screen-share source picker for xdg-desktop-portal-hyprland, built on fuzzel + slurp.
# Replaces the upstream Qt6 hyprland-share-picker (not built: bookworm Qt6 is
# libstdc++, the /opt/hypr stack is libc++). Wired in via ~/.config/hypr/xdph.conf.
#
# Protocol (xdg-desktop-portal-hyprland, src/shared/ScreencopyShared.cpp):
#   stdout:  [SELECTION]{flags}/screen:<output>
#            [SELECTION]{flags}/window:<id>
#            [SELECTION]{flags}/region:<output>@<x>,<y>,<w>,<h>   (x,y relative to output)
#   flags:   'r' = hand the app a restore token so it can re-share without asking.
#            XDPH passes --allow-token when screencopy:allow_token_by_default = 1.
#   env:     XDPH_WINDOW_SHARING_LIST = "<id>[HC>]<class>[HT>]<title>[HE>]<addr>[HA>]"...
#   Anything without [SELECTION] on stdout (or a non-zero exit) = cancelled.
set -u
HYPRCTL=/opt/hypr/bin/hyprctl
FUZZEL=/opt/hypr/bin/fuzzel
SLURP=/usr/bin/slurp

flag=""
for a in "$@"; do [ "$a" = "--allow-token" ] && flag="r"; done

entries=()
actions=()

# Screens
while IFS=$'\t' read -r name w h desc; do
	entries+=("Screen   ${name}  (${w}x${h}, ${desc})")
	actions+=("screen:${name}")
done < <("$HYPRCTL" monitors -j | jq -r '.[] | [.name, .width, .height, .description] | @tsv')

# Windows
list="${XDPH_WINDOW_SHARING_LIST:-}"
while [ -n "$list" ] && [[ "$list" == *"[HA>]"* ]]; do
	entry="${list%%\[HA>\]*}"
	list="${list#*\[HA>\]}"
	id="${entry%%\[HC>\]*}"
	rest="${entry#*\[HC>\]}"
	class="${rest%%\[HT>\]*}"
	rest="${rest#*\[HT>\]}"
	title="${rest%%\[HE>\]*}"
	[[ "$id" =~ ^[0-9]+$ ]] || continue
	entries+=("Window   ${class}: ${title}")
	actions+=("window:${id}")
done

entries+=("Region   drag to select an area")
actions+=("region")

idx=$(printf '%s\n' "${entries[@]}" |
	"$FUZZEL" --dmenu --index --log-level=error --prompt "Share  " \
		--lines "$(( ${#entries[@]} < 12 ? ${#entries[@]} : 12 ))" --width 70) || exit 1
[[ "$idx" =~ ^[0-9]+$ ]] || exit 1
sel="${actions[$idx]}"

if [ "$sel" = "region" ]; then
	read -r out x y w h < <("$SLURP" -f '%o %x %y %w %h') || exit 1
	[ -n "${h:-}" ] || exit 1
	read -r mx my < <("$HYPRCTL" monitors -j | jq -r --arg n "$out" '.[] | select(.name==$n) | "\(.x) \(.y)"')
	sel="region:${out}@$((x - ${mx:-0})),$((y - ${my:-0})),${w},${h}"
fi

printf '[SELECTION]%s/%s\n' "$flag" "$sel"

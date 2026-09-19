#!/usr/bin/env bash
# Bluetooth manager menu (fuzzel + bluetoothctl). Scanning runs in the background; the menu never blocks.
MENU="$HOME/.config/hypr/scripts/menu.sh"
notify() { command -v notify-send >/dev/null && notify-send "Bluetooth" "$1"; }
POWERED=$(bluetoothctl show | awk '/Powered:/{print $2}')
SCANNING=0; pgrep -f 'bluetoothctl scan on' >/dev/null && SCANNING=1

icon_for() { case "$1" in
  input-keyboard) echo 󰌌 ;; input-mouse) echo 󰍽 ;; audio-headset|audio-headphones) echo 󰋋 ;;
  audio-card) echo 󰓃 ;; phone) echo 󰄜 ;; computer) echo 󰇅 ;; *) echo 󰂯 ;; esac; }

MENU=""
if [ "$POWERED" = yes ]; then
  MENU+="󰂯  Bluetooth: on  (turn off)\n"
  if [ $SCANNING = 1 ]; then MENU+="󰑓  Scanning…  (select to refresh list)\n"; else MENU+="󰑓  Scan for new devices\n"; fi
  PAIRED=$(bluetoothctl devices Paired)
  while read -r _ mac name; do
    [ -z "$mac" ] && continue
    info=$(bluetoothctl info "$mac"); icon=$(icon_for "$(awk '/Icon:/{print $2}' <<<"$info")")
    if grep -q 'Connected: yes' <<<"$info"; then MENU+="$icon  $name  ✔ connected  [$mac]\n"
    else MENU+="$icon  $name  (paired)  [$mac]\n"; fi
  done <<<"$PAIRED"
  # discovered but unpaired (skip nameless devices that only show a MAC)
  while read -r _ mac name; do
    [ -z "$mac" ] && continue; grep -q "$mac" <<<"$PAIRED" && continue
    [[ "$name" =~ ^([0-9A-F]{2}-){5}[0-9A-F]{2}$ ]] && continue
    MENU+="󰂯  $name  [$mac]\n"
  done < <(bluetoothctl devices)
else
  MENU+="󰂲  Bluetooth: off  (turn on)\n"
fi
MENU+="󰒓  Open Blueman"

CHOICE=$(printf "$MENU" | "$MENU" -p "Bluetooth ")
[ -z "$CHOICE" ] && exit 0
MAC=$(grep -oE '\[[0-9A-F:]{17}\]' <<<"$CHOICE" | tr -d '[]')
NAME=$(sed -E 's/^[^ ]+  //; s/  (✔ connected|\(paired\))//; s/  \[[0-9A-F:]{17}\]$//' <<<"$CHOICE")
case "$CHOICE" in
  *"Bluetooth: on"*)  bluetoothctl power off >/dev/null; pkill -f 'bluetoothctl scan on'; notify "Turned off" ;;
  *"Bluetooth: off"*) bluetoothctl power on  >/dev/null; notify "Turned on" ;;
  *"Scan for new"*)   setsid -f timeout 30 bluetoothctl scan on >/dev/null 2>&1; sleep 0.3; exec "$0" ;;
  *"Scanning"*)       exec "$0" ;;
  *"Open Blueman"*)   exec blueman-manager ;;
  *"✔ connected"*)    bluetoothctl disconnect "$MAC" >/dev/null && notify "Disconnected $NAME" ;;
  *"(paired)"*)       bluetoothctl connect "$MAC" >/dev/null && notify "Connected $NAME" || notify "Failed to connect $NAME" ;;
  *)  [ -z "$MAC" ] && exit 0
      pkill -f 'bluetoothctl scan on'
      bluetoothctl trust "$MAC" >/dev/null
      if bluetoothctl pair "$MAC" >/dev/null 2>&1 && bluetoothctl connect "$MAC" >/dev/null 2>&1; then notify "Paired and connected $NAME"
      else notify "Pairing failed for $NAME (try Blueman for PIN prompts)"; fi ;;
esac

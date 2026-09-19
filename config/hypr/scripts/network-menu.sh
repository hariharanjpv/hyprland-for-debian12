#!/usr/bin/env bash
# Wi-Fi / network menu (fuzzel + nmcli)
#
# NOTE: fuzzel's --password does NOT work in dmenu mode, so unlike the wofi
# version the passphrase prompt is handed to `nmcli --ask` in a terminal,
# which masks input itself.
MENU="$HOME/.config/hypr/scripts/menu.sh"
TERM_EMU="${TERMINAL:-foot}"
notify() { command -v notify-send >/dev/null && notify-send "Network" "$1"; }

WIFI_DEV=$(nmcli -t -f DEVICE,TYPE dev status | awk -F: '$2=="wifi"{print $1; exit}')
WIFI_STATE=$(nmcli radio wifi)
WIRED=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev status | awk -F: '$2=="ethernet" && $3=="connected"{print $4}')

bars() { s=$1; if [ "$s" -ge 80 ]; then echo 󰤨; elif [ "$s" -ge 60 ]; then echo 󰤥; elif [ "$s" -ge 40 ]; then echo 󰤢; elif [ "$s" -ge 20 ]; then echo 󰤟; else echo 󰤯; fi; }

MENU_TXT=""
[ -n "$WIRED" ] && MENU_TXT+="󰈀  Wired: $WIRED\n"
if [ "$WIFI_STATE" = enabled ]; then
	MENU_TXT+="󰖩  Wi-Fi: on  (turn off)\n󰑓  Rescan / refresh\n"
	while IFS=: read -r act ssid sig sec; do
		[ -z "$ssid" ] && continue
		lock=""; [ -n "$sec" ] && [ "$sec" != "--" ] && lock=" 󰌾"
		if [ "$act" = yes ]; then MENU_TXT+="$(bars $sig)  $ssid$lock  ✔ connected\n"
		else MENU_TXT+="$(bars $sig)  $ssid$lock\n"; fi
	done < <(nmcli -t -f ACTIVE,SSID,SIGNAL,SECURITY dev wifi list | sort -t: -k1,1r -k3,3nr | awk -F: '!seen[$2]++')
else
	MENU_TXT+="󰖪  Wi-Fi: off  (turn on)\n"
fi
MENU_TXT+="󰒓  Edit connections"

CHOICE=$(printf "$MENU_TXT" | "$MENU" -p "Network ")
[ -z "$CHOICE" ] && exit 0
case "$CHOICE" in
*"Wi-Fi: on"*) nmcli radio wifi off; notify "Wi-Fi turned off" ;;
*"Wi-Fi: off"*) nmcli radio wifi on; notify "Wi-Fi turned on" ;;
*Rescan*) (nmcli dev wifi rescan >/dev/null 2>&1 &); exec "$0" ;;
*"Edit connections"*) exec nm-connection-editor ;;
*Wired:*) exit 0 ;;
*connected*)
	SSID=$(sed -E 's/^[^ ]+  //; s/( 󰌾)?  ✔ connected$//' <<<"$CHOICE")
	nmcli con down id "$SSID" >/dev/null 2>&1 && notify "Disconnected from $SSID" ;;
*)
	SSID=$(sed -E 's/^[^ ]+  //; s/ 󰌾$//' <<<"$CHOICE")
	if nmcli -t -f NAME con show | grep -Fxq "$SSID"; then
		nmcli con up id "$SSID" >/dev/null 2>&1 && notify "Connected to $SSID" || notify "Failed to connect to $SSID"
	elif [[ "$CHOICE" == *󰌾* ]]; then
		# secured and unknown -> let nmcli prompt for the passphrase itself
		"$TERM_EMU" -T "Wi-Fi: $SSID" -e nmcli --ask dev wifi connect "$SSID" ifname "$WIFI_DEV"
	else
		OUT=$(nmcli dev wifi connect "$SSID" ifname "$WIFI_DEV" 2>&1)
		[[ "$OUT" == *successfully* ]] && notify "Connected to $SSID" || { notify "Failed: $OUT"; nmcli con delete id "$SSID" >/dev/null 2>&1; }
	fi ;;
esac

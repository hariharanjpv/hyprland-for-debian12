#!/bin/bash
# --inc | --dec | --toggle | --mic | --toggle-mic | --mic-inc | --mic-dec
cap() { pactl get-sink-volume @DEFAULT_SINK@ | grep -qE '\b1[0-9]{2}%' && pactl set-sink-volume @DEFAULT_SINK@ 100%; }
case "$1" in
  --inc)        pactl set-sink-volume @DEFAULT_SINK@ +5%; cap ;;
  --dec)        pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
  --toggle)     pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
  --mic|--toggle-mic) pactl set-source-mute @DEFAULT_SOURCE@ toggle ;;
  --mic-inc)    pactl set-source-volume @DEFAULT_SOURCE@ +5% ;;
  --mic-dec)    pactl set-source-volume @DEFAULT_SOURCE@ -5% ;;
  *) echo "usage: $0 --inc|--dec|--toggle|--toggle-mic|--mic-inc|--mic-dec" >&2; exit 1 ;;
esac

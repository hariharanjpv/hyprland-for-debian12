#!/bin/bash
# --inc | --dec  (5% steps) via logind, no root needed
DEV=$(ls /sys/class/backlight | head -1); [ -z "$DEV" ] && exit 0
MAX=$(cat /sys/class/backlight/$DEV/max_brightness); CUR=$(cat /sys/class/backlight/$DEV/brightness)
STEP=$(( MAX / 20 )); [ "$STEP" -lt 1 ] && STEP=1
case "$1" in
  --inc) NEW=$(( CUR + STEP )) ;;
  --dec) NEW=$(( CUR - STEP )) ;;
  *) echo "usage: $0 --inc|--dec"; exit 1 ;;
esac
[ "$NEW" -gt "$MAX" ] && NEW=$MAX; [ "$NEW" -lt 1 ] && NEW=1
busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto \
  org.freedesktop.login1.Session SetBrightness ssu backlight "$DEV" "$NEW"

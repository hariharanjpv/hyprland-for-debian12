#!/usr/bin/env bash
# Build Hyprland (+ hyprlock, waybar) from source on Debian 12 bookworm.
#
#   ./build.sh              run every step, skipping what is already built
#   ./build.sh 03 04        run only those steps
#   ./build.sh --list       show the steps
#
# Every step is idempotent: re-running after a failure resumes rather than
# redoing finished work.
set -euo pipefail
cd "$(dirname "$0")"

STEPS=(00-apt 01-toolchain 02-c-core 03-cpp-deps 04-hypr-libs 05-hyprland 06-hyprlock 07-waybar 08-fuzzel 09-xdph)

if [ "${1:-}" = "--list" ]; then
	printf '%s\n' "${STEPS[@]}"; exit 0
fi

WANT=("$@")
run_step() {
	local s=$1
	if [ ${#WANT[@]} -gt 0 ]; then
		local match=0
		for w in "${WANT[@]}"; do [[ "$s" == "$w"* ]] && match=1; done
		[ $match = 1 ] || return 0
	fi
	printf '\n\e[1;34m######## %s\e[0m\n' "$s"
	bash "build/$s.sh"
}

[ "$(. /etc/os-release; echo "$VERSION_ID")" = "12" ] || {
	echo "WARNING: this targets Debian 12 (bookworm). Proceeding anyway." >&2; }

for s in "${STEPS[@]}"; do run_step "$s"; done

cat <<'DONE'

────────────────────────────────────────────────────────────────────
Build complete.

  1. Install the configs:        ./install-config.sh
  2. Register the session:       ./install-session.sh
  3. Enable screen sharing:      ./install-portal.sh
  4. Log out, pick "Hyprland" at your display manager.

  Do NOT just copy /opt/hypr/share/wayland-sessions/hyprland.desktop --
  its Exec relies on /opt/hypr/bin being on PATH, which a display
  manager does not provide. install-session.sh handles this.

  Or test first WITHOUT touching your current session:
     Ctrl+Alt+F3 -> log in -> hypr

  NOTE: Hyprland cannot be tested nested inside sway or another older
  compositor. See docs/gotchas.md "Testing".
────────────────────────────────────────────────────────────────────
DONE

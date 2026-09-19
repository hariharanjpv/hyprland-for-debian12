#!/usr/bin/env bash
# hyprlock — the lock screen. Needs sdbus-c++ and date from 03-cpp-deps.sh.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

have_pc sdbus-c++ || die "sdbus-c++ missing — run build/03-cpp-deps.sh first"

if ! have_bin hyprlock; then
	fetch_git https://github.com/hyprwm/hyprlock.git "$HYPRLOCK_TAG" hyprlock
	cmake_build hyprlock
fi

assert_libcxx "$PREFIX/bin/hyprlock"
step "hyprlock $("$PREFIX/bin/hyprlock" --version 2>/dev/null | head -1)"
info "PAM config: hyprlock installs /etc/pam.d/hyprlock; if unlocking fails,"
info "check that file exists and references common-auth"

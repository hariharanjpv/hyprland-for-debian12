#!/usr/bin/env bash
# xdg-desktop-portal-hyprland — screen sharing / screenshots for Discord,
# browsers, conferencing apps. Without it, "share screen" offers nothing.
#
# BUILD_SHARE_PICKER=OFF on purpose: the upstream picker is Qt6, and bookworm's
# Qt6 is libstdc++ while this whole prefix is libc++ (docs/why-libcxx.md).
# Linking them would be the exact ABI mix that corrupts at runtime. A fuzzel +
# slurp picker in config/hypr/scripts/share-picker.sh replaces it — no Qt at
# all, and it matches the rest of the menus.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

[ -x "$PREFIX/libexec/xdg-desktop-portal-hyprland" ] && { info "xdph already built"; exit 0; }

have_pc sdbus-c++        || die "sdbus-c++ missing — run build/03-cpp-deps.sh"
have_pc hyprland-protocols || die "hyprland-protocols missing — run build/04-hypr-libs.sh"
have_pc libpipewire-0.3  || die "libpipewire-0.3-dev missing — run build/00-apt.sh"

fetch_git https://github.com/hyprwm/xdg-desktop-portal-hyprland.git "$XDPH_TAG" xdg-desktop-portal-hyprland
cmake_build xdg-desktop-portal-hyprland -DBUILD_SHARE_PICKER=OFF

assert_libcxx "$PREFIX/libexec/xdg-desktop-portal-hyprland"
step "xdph built"
info "it is NOT active until registered — run ./install-portal.sh"

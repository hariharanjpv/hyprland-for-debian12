#!/usr/bin/env bash
# Hyprland itself.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

# --recursive is NOT optional: Hyprland vendors udis86, hyprland-protocols and
# tracy as submodules. A plain --depth 1 clone leaves them empty and configure
# fails confusingly.
fetch_git https://github.com/hyprwm/Hyprland.git "$HYPRLAND_TAG" Hyprland --recursive

# Patch: meta/generateLuaStubs.py uses PEP 695 `type X = Y` syntax, new in
# Python 3.12. Debian 12 ships 3.11, so the build dies with a SyntaxError
# before compiling any C++. The script only generates LuaLS editor stubs, and
# CMake offers no flag to skip it — the target is ALL and both Hyprland and
# hyprland_lib depend on it.
if grep -q '^type ' "$SRC_DIR/Hyprland/meta/generateLuaStubs.py" 2>/dev/null; then
	step "patching generateLuaStubs.py for Python 3.11"
	patch -p1 -d "$SRC_DIR/Hyprland" < "$HERE/patches/hyprland-generateLuaStubs-pep695.patch" \
		|| die "patch failed — see patches/ and docs/gotchas.md"
fi

# Patch: Debian 12 ships Xwayland 22.1.9, which predates xwayland-shell-v1 /
# WL_SURFACE_SERIAL (Xwayland 23.1) and still uses the legacy WL_SURFACE_ID
# client message. Hyprland's WL_SURFACE_ID branch only associates the X surface
# if the wl_surface resource ALREADY exists -- it never records the id, so the
# later onNewSurface() match can never succeed.
#
# Result: NO X11 WINDOW EVER APPEARS. Not a crash, not an error -- the window
# simply never maps, and Hyprland logs nothing because debug:disable_logs
# defaults to true. xwininfo shows it as IsViewable while hyprctl clients is
# empty.
#
# Harmless on systems with Xwayland >= 23.1: it sets a field the modern path
# does not consult.
if ! grep -q 'XSURF->m_wlID = id;' "$SRC_DIR/Hyprland/src/xwayland/XWM.cpp"; then
	step "patching XWM.cpp for Xwayland < 23.1"
	patch -p1 -d "$SRC_DIR/Hyprland" < "$HERE/patches/hyprland-xwayland-wl-surface-id.patch" \
		|| die "XWM patch failed — see docs/gotchas.md"
fi

cmake_build Hyprland
step "Hyprland installed"

info "verifying the binary"
objdump -p "$PREFIX/bin/Hyprland" | grep -q 'NEEDED.*libstdc++' \
	&& die "Hyprland links libstdc++ — ABI violation"
ldd "$PREFIX/bin/Hyprland" | grep -q 'not found' \
	&& die "Hyprland has unresolved libraries — rpath problem"
info "$("$PREFIX/bin/Hyprland" --version 2>/dev/null | head -1)"

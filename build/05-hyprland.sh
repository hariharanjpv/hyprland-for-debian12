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

cmake_build Hyprland
step "Hyprland installed"

info "verifying the binary"
objdump -p "$PREFIX/bin/Hyprland" | grep -q 'NEEDED.*libstdc++' \
	&& die "Hyprland links libstdc++ — ABI violation"
ldd "$PREFIX/bin/Hyprland" | grep -q 'not found' \
	&& die "Hyprland has unresolved libraries — rpath problem"
info "$("$PREFIX/bin/Hyprland" --version 2>/dev/null | head -1)"

#!/usr/bin/env bash
# Waybar 0.15 into its OWN prefix (/opt/waybar), separate from /opt/hypr.
#
# Why a separate prefix: waybar is a GTK3 app built against Debian's
# libstdc++ C++ stack (gtkmm, spdlog, fmt, jsoncpp are all libstdc++).
# It must NOT be built with libc++ or it would mix ABIs with gtkmm.
# Keeping it out of /opt/hypr keeps the two toolchains from meeting.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

[ -x "$WAYBAR_PREFIX/bin/waybar" ] && { info "waybar already built"; exit 0; }

fetch_git https://github.com/Alexays/Waybar.git "$WAYBAR_TAG" Waybar

step "meson: Waybar $WAYBAR_TAG -> $WAYBAR_PREFIX"
sudo mkdir -p "$WAYBAR_PREFIX"
sudo chown "$USER:$USER" "$WAYBAR_PREFIX"

# NOTE: default toolchain here (gcc/libstdc++), NOT the libc++ env.
# cava is disabled: its subproject needs network access at configure time and
# pulls in fftw/iniparser for a visualiser most people do not use.
env -u CC -u CXX -u CXXFLAGS -u LDFLAGS -u PKG_CONFIG_PATH -u LD_LIBRARY_PATH \
	meson setup "$SRC_DIR/Waybar/build" "$SRC_DIR/Waybar" \
		--prefix="$WAYBAR_PREFIX" --buildtype=release \
		-Dcpp_std=c++20 -Dcava=disabled -Dexperimental=false
ninja -C "$SRC_DIR/Waybar/build" install

step "waybar $("$WAYBAR_PREFIX/bin/waybar" --version 2>/dev/null | head -1)"
info "not on PATH by design — start it with the absolute path:"
info "  exec-once = $WAYBAR_PREFIX/bin/waybar"

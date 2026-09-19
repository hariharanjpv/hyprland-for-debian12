#!/usr/bin/env bash
# Pure-C libraries. No libc++/libstdc++ ABI concern here — C has no name
# mangling or templates, so the compiler choice is irrelevant to linkage.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

# wayland 1.26 (bookworm: 1.21) ------------------------------------------------
if ! have_pc 'wayland-server >= 1.23'; then
	fetch_git https://gitlab.freedesktop.org/wayland/wayland.git "$WAYLAND_VER" wayland
	meson_build wayland -Ddocumentation=false -Dtests=false
fi

# wayland-protocols 1.49 (bookworm: 1.31) -------------------------------------
if ! have_pc 'wayland-protocols >= 1.41'; then
	fetch_git https://gitlab.freedesktop.org/wayland/wayland-protocols.git "$WAYLAND_PROTOCOLS_VER" wayland-protocols
	meson_build wayland-protocols -Dtests=false
fi

# libdrm (not installed on a stock bookworm desktop) --------------------------
if ! have_pc 'libdrm >= 2.4.120'; then
	fetch_git https://gitlab.freedesktop.org/mesa/libdrm.git "$LIBDRM_TAG" libdrm
	meson_build libdrm -Dman-pages=disabled
fi

# libdisplay-info — absent from Debian entirely -------------------------------
# PINNED to 0.2.0: this is aquamarine's declared floor and the library is
# pre-1.0, so its API can break between minor releases. Do not "update".
if ! have_pc libdisplay-info; then
	fetch_git https://gitlab.freedesktop.org/emersion/libdisplay-info.git "$LIBDISPLAY_INFO_VER" libdisplay-info
	meson_build libdisplay-info
fi

# xcb-util-errors — absent from bookworm (trixie+ only) -----------------------
# From the RELEASE TARBALL, not git: the git repo's m4 submodule points at
# git://anongit.freedesktop.org/, decommissioned years ago, so autogen.sh
# exits before doing anything. Tarballs ship configure pre-generated.
if ! have_pc xcb-errors; then
	fetch_tar "https://xorg.freedesktop.org/archive/individual/lib/xcb-util-errors-$XCB_UTIL_ERRORS_VER.tar.xz" \
		"xcb-util-errors-$XCB_UTIL_ERRORS_VER"
	step "autotools: xcb-util-errors"
	( cd "$SRC_DIR/xcb-util-errors-$XCB_UTIL_ERRORS_VER" \
	  && ./configure --prefix="$PREFIX" && make -j"$(nproc)" && make install )
fi

# libxkbcommon >= 1.11 (bookworm: 1.5.0) --------------------------------------
if ! have_pc 'xkbcommon >= 1.11.0'; then
	fetch_git https://github.com/xkbcommon/libxkbcommon.git "$XKBCOMMON_TAG" libxkbcommon
	meson_build libxkbcommon -Denable-docs=false -Denable-wayland=false -Denable-tools=false
fi

# libinput >= 1.29 (bookworm: 1.22.1) -----------------------------------------
# -Dlibwacom=false avoids pulling GTK3 in for a debug GUI. Costs tablet quirks.
if ! have_pc 'libinput >= 1.29'; then
	fetch_git https://gitlab.freedesktop.org/libinput/libinput.git "$LIBINPUT_TAG" libinput
	meson_build libinput -Dtests=false -Ddebug-gui=false -Ddocumentation=false -Dlibwacom=false
fi

# libseat >= 0.8 (bookworm: 0.7.0) --------------------------------------------
# -Dserver=disabled: we want the library only. logind is already the seat
# manager; a second seatd daemon would just fight it.
if ! have_pc 'libseat >= 0.8.0'; then
	fetch_git https://github.com/kennylevinsen/seatd.git "$SEATD_TAG" seatd
	meson_build seatd -Dlibseat-logind=systemd -Dserver=disabled -Dexamples=disabled -Dman-pages=disabled
fi

# libei — absent from bookworm; Hyprland requires libeis-1.0 ------------------
if ! have_pc libeis-1.0; then
	fetch_git https://gitlab.freedesktop.org/libinput/libei.git "$LIBEI_TAG" libei
	meson_build libei -Dtests=disabled -Dliboeffis=disabled -Ddocumentation=
fi

# cairo >= 1.17.2 (bookworm: 1.16.0) ------------------------------------------
# Hyprland's GLRenderer.cpp uses CAIRO_FORMAT_RGB96F, a float surface format
# added in 1.17.2. Hyprland declares bare `cairo` with NO version floor, so
# this only fails at COMPILE time, ~700 objects in.
if ! pkg-config --atleast-version=1.17.2 cairo 2>/dev/null; then
	fetch_git https://gitlab.freedesktop.org/cairo/cairo.git "$CAIRO_VER" cairo
	meson_build cairo -Dtests=disabled -Dsymbol-lookup=disabled
fi

step "C core done"

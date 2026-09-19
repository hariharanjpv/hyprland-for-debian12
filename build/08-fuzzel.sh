#!/usr/bin/env bash
# fuzzel — the launcher hypr-menu is built on.
#
# Debian 12 ships 1.8.2 (2023). Build 1.12 instead.
#
# The reason that matters: 1.8.2 has NO MOUSE SELECTION in dmenu mode, so
# every entry in hypr-menu is keyboard-only — you can see the items but not
# click them. 1.12 makes them clickable, which is what turns the nested menus
# into something usable with a trackpad.
#
# It also adds --match-mode and placeholder/counter colours; 1.8.2 rejects
# those keys outright with "key/value pair has no value".
#
# It also requires wayland-protocols >= 1.32 and bookworm has 1.31 — so this
# MUST be built with the prefix env sourced, after 02-c-core.sh.
#
# fuzzel is C: no libc++/libstdc++ ABI concern.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

have_bin fuzzel && { info "fuzzel already built"; exit 0; }

have_pc 'wayland-protocols >= 1.32' \
	|| die "wayland-protocols >= 1.32 missing — run build/02-c-core.sh first"

fetch_git https://codeberg.org/dnkl/fuzzel.git "$FUZZEL_TAG" fuzzel
meson_build fuzzel \
	-Denable-cairo=enabled \
	-Dpng-backend=libpng \
	-Dsvg-backend=nanosvg \
	-Dsystem-nanosvg=disabled

step "fuzzel $("$PREFIX/bin/fuzzel" --version 2>&1 | head -1)"
info "note: $PREFIX/bin comes before /usr/bin in the session PATH, so this"
info "      shadows any fuzzel installed from apt"

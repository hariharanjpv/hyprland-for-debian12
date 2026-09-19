#!/usr/bin/env bash
# Debian packages. Everything here is either a build tool or a -dev header.
# Nothing replaces a runtime library the running desktop depends on.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

PKGS=(
	# toolchain: clang-19 + libc++ is the whole trick, see docs/why-libcxx.md
	clang-19 libc++-19-dev libc++abi-19-dev lld-19
	ninja-build git pkg-config python3-pip python3-venv curl
	bison flex autoconf automake libtool xutils-dev
	# python modules used at build time by libei + Hyprland's codegen
	python3-attr python3-jinja2 python3-xcbgen xcb-proto
	# C libraries (safe: no C++ ABI surface)
	libxcursor-dev liblcms2-dev libreadline-dev hwdata
	libpugixml-dev libzip-dev libjpeg-dev libwebp-dev libspng-dev
	libmagic-dev libcairo2-dev libpango1.0-dev librsvg2-dev
	libxkbcommon-dev libinput-dev libseat-dev libgbm-dev
	libegl1-mesa-dev libgles2-mesa-dev libudev-dev libsystemd-dev
	libxcb-util-dev libxcb-composite0-dev libxcb-render0-dev
	libxcb-res0-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-xkb-dev
	libpam0g-dev libxml2-dev libpng-dev uuid-dev
	xwayland
	# fuzzel
	libfcft-dev libtllist-dev libpixman-1-dev libfontconfig-dev
	# waybar
	libfmt-dev libspdlog-dev libgtkmm-3.0-dev libgtk-layer-shell-dev
	libjsoncpp-dev libsigc++-2.0-dev libnl-3-dev libnl-genl-3-dev
	libpulse-dev libmpdclient-dev libplayerctl-dev libevdev-dev
	scdoc
)

step "apt packages (${#PKGS[@]})"
warn "NOTE: libxcb-errors-dev does NOT exist in bookworm (trixie+ only)."
warn "      apt aborts the WHOLE transaction on one unknown name, so it is"
warn "      built from source in 02-c-core.sh instead."

sudo apt update
sudo apt install -y "${PKGS[@]}"
step "apt done"

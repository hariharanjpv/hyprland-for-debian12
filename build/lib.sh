#!/usr/bin/env bash
# Shared helpers for every build step. Sourced, never executed directly.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$HERE/versions.env"

BOLD=$'\e[1m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; RED=$'\e[31m'; RESET=$'\e[0m'
step() { printf '%s==> %s%s\n' "$BOLD$GREEN" "$*" "$RESET"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%s !! %s%s\n' "$YELLOW" "$*" "$RESET" >&2; }
die()  { printf '%s !! %s%s\n' "$RED" "$*" "$RESET" >&2; exit 1; }

need_env() {
	[ -f "$PREFIX/env.sh" ] || die "$PREFIX/env.sh missing — run build/01-toolchain.sh first"
	# shellcheck disable=SC1090
	source "$PREFIX/env.sh"
}

# Skip a step if its output already exists. Makes the whole build resumable:
# re-running build.sh after a failure does not redo finished work.
have_pc()  { pkg-config --exists "$1" 2>/dev/null; }
have_bin() { [ -x "$PREFIX/bin/$1" ]; }

fetch_git() { # fetch_git <url> <tag> <dirname> [--recursive]
	local url=$1 tag=$2 dir=$3; shift 3
	mkdir -p "$SRC_DIR"
	if [ -d "$SRC_DIR/$dir/.git" ]; then
		info "$dir already cloned"
	else
		info "cloning $dir @ $tag"
		git clone --depth 1 -b "$tag" "$@" "$url" "$SRC_DIR/$dir"
	fi
}

fetch_tar() { # fetch_tar <url> <dirname>
	local url=$1 dir=$2 file
	file=$(basename "$url")
	mkdir -p "$SRC_DIR"
	[ -d "$SRC_DIR/$dir" ] && { info "$dir already extracted"; return; }
	info "downloading $file"
	curl -fL --retry 3 -o "$SRC_DIR/$file" "$url"
	tar xf "$SRC_DIR/$file" -C "$SRC_DIR"
}

meson_build() { # meson_build <dir> [meson args...]
	local dir=$1; shift
	step "meson: $dir"
	meson setup "$SRC_DIR/$dir/build" "$SRC_DIR/$dir" \
		--prefix="$PREFIX" --buildtype=release "$@"
	ninja -C "$SRC_DIR/$dir/build" install
}

cmake_build() { # cmake_build <dir> [cmake args...]
	local dir=$1; shift
	step "cmake: $dir"
	# NOTE: never pass -DCMAKE_CXX_FLAGS here. CMake absorbs CXXFLAGS/LDFLAGS
	# from the environment on FIRST configure; passing the flag explicitly
	# OVERRIDES that and silently drops the rpath from LDFLAGS.
	cmake -S "$SRC_DIR/$dir" -B "$SRC_DIR/$dir/build" -G Ninja \
		-DCMAKE_INSTALL_PREFIX="$PREFIX" \
		-DCMAKE_PREFIX_PATH="$PREFIX" \
		-DCMAKE_BUILD_TYPE=Release "$@"
	ninja -C "$SRC_DIR/$dir/build" install
}

# Verify a C++ artefact links libc++ and NOT libstdc++.
# Use objdump (direct DT_NEEDED), never ldd — ldd prints the whole transitive
# closure and will report false positives via gdk-pixbuf/rsvg.
assert_libcxx() {
	local f=$1
	[ -e "$f" ] || return 0
	if objdump -p "$f" 2>/dev/null | grep -q 'NEEDED.*libstdc++'; then
		die "ABI violation: $(basename "$f") links libstdc++ directly. See docs/why-libcxx.md"
	fi
}

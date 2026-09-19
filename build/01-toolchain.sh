#!/usr/bin/env bash
# Build prefix + a CMake and meson new enough for the hyprwm stack.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

step "prefix $PREFIX"
sudo mkdir -p "$PREFIX"
sudo chown "$USER:$USER" "$PREFIX"
# Owning the prefix means every `ninja install` below runs WITHOUT sudo.
# A build that needs root to install is a build that can scribble outside
# its prefix when a path is wrong.

if [ ! -x "$PREFIX/bin/cmake" ]; then
	step "cmake $CMAKE_VER"
	# Deliberately 3.x: CMake 4 dropped cmake_minimum_required(VERSION <3.5)
	# and hard-errors on older projects. Several deps here still declare one.
	fetch_tar "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-linux-x86_64.tar.gz" \
		"cmake-$CMAKE_VER-linux-x86_64"
	cp -r "$SRC_DIR/cmake-$CMAKE_VER-linux-x86_64/." "$PREFIX/"
fi

if [ ! -x "$PREFIX/venv/bin/meson" ]; then
	step "meson (venv)"
	# venv because Debian marks its python externally-managed (PEP 668)
	python3 -m venv "$PREFIX/venv"
	"$PREFIX/venv/bin/pip" install -q -U meson
fi
# Symlink rather than putting venv/bin on PATH: that would shadow the system
# python3, and venvs cannot see /usr/lib/python3/dist-packages — which breaks
# xcbgen for libei and autotools' AM_PATH_PYTHON.
ln -sf "$PREFIX/venv/bin/meson" "$PREFIX/bin/meson"

step "env.sh"
sed "s|@PREFIX@|$PREFIX|g" "$HERE/build/env.sh.in" > "$PREFIX/env.sh"

need_env
step "verifying libc++ really provides C++23"
cat > /tmp/_libcxx_check.cc <<'CHK'
#include <format>
#include <expected>
#include <print>
int main() { std::print("{}\n", std::format("{}-{}", 42, "ok")); return 0; }
CHK
clang++-19 -stdlib=libc++ -std=c++23 /tmp/_libcxx_check.cc -o /tmp/_libcxx_check \
	|| die "libc++ cannot compile C++23 — see docs/why-libcxx.md"
/tmp/_libcxx_check | grep -q '42-ok' || die "libc++ check produced wrong output"
rm -f /tmp/_libcxx_check /tmp/_libcxx_check.cc
info "libc++ C++23 OK — <format>, <expected>, <print> all work"
step "toolchain done: cmake $(cmake --version | head -1), meson $(meson --version)"

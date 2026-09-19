#!/usr/bin/env bash
# C++ dependencies. EVERY one of these must be built with libc++.
#
# Debian's C++ shared libraries are libstdc++-built. Linking one into a libc++
# binary mixes two standard libraries in a single process: it links cleanly and
# corrupts at runtime wherever a std:: type crosses the boundary, because
# std::string has a different memory layout in each. See docs/why-libcxx.md.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

# glslang — C++ API, Debian's 12.0.0 is libstdc++ ------------------------------
# -DENABLE_OPT=OFF skips the SPIRV-Tools optimiser we do not need.
# Ships NO .pc file by design: it is CMake-config only, found via
# CMAKE_PREFIX_PATH. `pkg-config glslang` failing is CORRECT, not a fault.
if [ ! -f "$PREFIX/lib/cmake/glslang/glslang-config.cmake" ]; then
	fetch_git https://github.com/KhronosGroup/glslang.git "$GLSLANG_TAG" glslang
	cmake_build glslang -DBUILD_SHARED_LIBS=ON -DENABLE_OPT=OFF -DGLSLANG_TESTS=OFF
fi

# re2 — PINNED PRE-ABSEIL -----------------------------------------------------
# 2022-06-01 has zero Abseil references; 2025-08-12 has 23. Modern re2 would
# drag in Abseil, which would itself need a libc++ rebuild. Hyprland declares
# bare `re2` with no floor, so the old one is fine.
# Upstream ships no .pc (Debian authors theirs downstream) -> written below.
if ! have_pc re2; then
	fetch_git https://github.com/google/re2.git "$RE2_TAG" re2
	cmake_build re2 -DBUILD_SHARED_LIBS=ON -DRE2_BUILD_TESTING=OFF
	sed "s|@PREFIX@|$PREFIX|g; s|@VERSION@|${RE2_TAG//-/.}|g" \
		"$HERE/pkgconfig/re2.pc.in" > "$PREFIX/lib/pkgconfig/re2.pc"
fi

# muparser — C++ API ----------------------------------------------------------
if ! have_pc muparser; then
	fetch_git https://github.com/beltoforion/muparser.git "$MUPARSER_TAG" muparser
	cmake_build muparser -DBUILD_SHARED_LIBS=ON -DENABLE_SAMPLES=OFF -DENABLE_OPENMP=OFF
fi

# tomlplusplus — HEADER-ONLY, deliberately ------------------------------------
# Two bugs, one fix. (1) Debian ships 3.3.0 whose header is toml++/toml.h;
# hyprcursor includes toml++/toml.hpp, added in 3.4.0 — and hyprcursor declares
# bare `tomlplusplus` with no floor, so it only fails at compile time.
# (2) Debian's compiled libtomlplusplus is libstdc++ and its API is saturated
# with std::string/string_view/optional — the dangerous ABI case.
# TOML_HEADER_ONLY=1 compiles it into the consumer with the consumer's stdlib:
# no shared library, no ABI boundary. Note the .pc has NO Libs: line.
if ! pkg-config --atleast-version=3.4.0 tomlplusplus 2>/dev/null; then
	fetch_git https://github.com/marzer/tomlplusplus.git "$TOMLPLUSPLUS_TAG" tomlplusplus
	cp -r "$SRC_DIR/tomlplusplus/include/toml++" "$PREFIX/include/"
	mkdir -p "$PREFIX/lib/pkgconfig"
	sed "s|@PREFIX@|$PREFIX|g; s|@VERSION@|${TOMLPLUSPLUS_TAG#v}|g" \
		"$HERE/pkgconfig/tomlplusplus.pc.in" > "$PREFIX/lib/pkgconfig/tomlplusplus.pc"
fi

# Lua 5.5 — Hyprland pins >=5.5,<5.6; Debian maxes at 5.4.4 -------------------
# MYCFLAGS=-fPIC is mandatory: liblua.a is static and gets linked into shared
# objects. Without it the failure appears as a Hyprland link error.
# Upstream ships no .pc (its `pc:` target only PRINTS variables).
if ! have_pc lua5.5; then
	fetch_tar "https://www.lua.org/ftp/lua-$LUA_VER.tar.gz" "lua-$LUA_VER"
	step "make: lua $LUA_VER"
	( cd "$SRC_DIR/lua-$LUA_VER" && make all MYCFLAGS=-fPIC && make install INSTALL_TOP="$PREFIX" )
	sed "s|@PREFIX@|$PREFIX|g; s|@VERSION@|$LUA_VER|g" \
		"$HERE/pkgconfig/lua5.5.pc.in" > "$PREFIX/lib/pkgconfig/lua5.5.pc"
fi

# sdbus-c++ — required by hyprlock; absent from bookworm ----------------------
if ! have_pc sdbus-c++; then
	fetch_git https://github.com/Kistler-Group/sdbus-cpp.git "$SDBUS_CPP_TAG" sdbus-cpp
	cmake_build sdbus-cpp -DBUILD_SHARED_LIBS=ON -DSDBUSCPP_BUILD_CODEGEN=OFF \
		-DSDBUSCPP_BUILD_TESTS=OFF -DSDBUSCPP_BUILD_DOCS=OFF
fi

# date (Howard Hinnant) — hyprlock links libdate-tz ---------------------------
if [ ! -f "$PREFIX/lib/cmake/date/dateConfig.cmake" ] && [ ! -f "$PREFIX/lib/libdate-tz.so" ]; then
	fetch_git https://github.com/HowardHinnant/date.git "$DATE_TAG" date
	cmake_build date -DBUILD_SHARED_LIBS=ON -DBUILD_TZ_LIB=ON \
		-DUSE_SYSTEM_TZ_DB=ON -DENABLE_DATE_TESTING=OFF
fi

step "C++ deps done — verifying ABI"
for f in "$PREFIX"/lib*/libre2.so.* "$PREFIX"/lib*/libmuparser.so.* "$PREFIX"/lib*/libglslang.so.*; do
	assert_libcxx "$f"
done
info "no direct libstdc++ linkage found"

#!/usr/bin/env bash
# The hyprwm library stack. Strict order — each needs the ones above it.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
need_env

hypr() { # hypr <repo> <tag> [extra cmake args]
	local repo=$1 tag=$2; shift 2
	fetch_git "https://github.com/hyprwm/$repo.git" "$tag" "$repo"
	cmake_build "$repo" "$@"
}

have_bin hyprwayland-scanner || hypr hyprwayland-scanner "$HYPRWAYLAND_SCANNER_TAG"
have_pc hyprutils            || hypr hyprutils   "$HYPRUTILS_TAG"
have_pc hyprlang             || hypr hyprlang    "$HYPRLANG_TAG"
have_pc hyprcursor           || hypr hyprcursor  "$HYPRCURSOR_TAG"
have_pc hyprgraphics         || hypr hyprgraphics "$HYPRGRAPHICS_TAG"
have_pc aquamarine           || hypr aquamarine  "$AQUAMARINE_TAG"
have_pc hyprwire             || hypr hyprwire    "$HYPRWIRE_TAG"
have_pc hyprland-protocols   || hypr hyprland-protocols "$HYPRLAND_PROTOCOLS_TAG"

step "hypr libs done — verifying ABI"
for f in "$PREFIX"/lib*/libhypr*.so.* "$PREFIX"/lib*/libaquamarine.so.*; do
	assert_libcxx "$f"
done
info "all hypr libraries link libc++ only"

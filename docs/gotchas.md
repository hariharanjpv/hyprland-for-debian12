# Gotchas

Every wall hit building this, with the error text so search can find it.
Ordered roughly as you'd meet them.

---

## `E: Unable to locate package libxcb-errors-dev`

Not in bookworm — trixie and later only. **apt aborts the entire transaction on
one unknown name**, so a single bad entry installs none of the other 30.

Built from source in `02-c-core.sh` instead. When hand-writing a long package
list, check names first:

```bash
for p in <list>; do apt-cache policy "$p" | grep -q Candidate || echo "MISSING $p"; done
```

---

## `xcb-util-errors`: `You have uninitialized git submodules`

The git repo's `m4` submodule points at `git://anongit.freedesktop.org/`,
decommissioned years ago, so `autogen.sh` exits before doing anything.

**Use the release tarball**, which ships `configure` pre-generated with the m4
macros vendored in:

```
https://xorg.freedesktop.org/archive/individual/lib/xcb-util-errors-1.0.1.tar.xz
```

> **Rule:** for autotools projects prefer the release tarball; for meson/cmake,
> a git checkout is fine — they have no equivalent bootstrap step.

---

## `ModuleNotFoundError: No module named 'xcbgen'`

Caused by putting the meson venv on `PATH`. A venv cannot see
`/usr/lib/python3/dist-packages`, so it shadows the system python for
`AM_PATH_PYTHON` and for libei's code generation.

**Fix:** symlink meson into `$PREFIX/bin` instead of adding `venv/bin` to
`PATH`. A script carries its own interpreter in its shebang.

> Env scripts are **additive, not declarative** — re-sourcing cannot remove
> what a previous source added. After editing `env.sh`, run `exec bash`.

---

## `fatal error: 'toml++/toml.hpp' file not found`

Debian ships tomlplusplus **3.3.0**, whose header is `toml++/toml.h`.
hyprcursor includes `toml++/toml.hpp`, added in **3.4.0**.

hyprcursor declares bare `tomlplusplus` with **no version floor**, so
pkg-config accepts 3.3.0 and the mismatch only appears at compile time.

Fixed by installing 3.4.0 headers **header-only** — which also removes an ABI
hazard, since Debian's compiled library is libstdc++. See
[why-libcxx.md](why-libcxx.md).

---

## `Package 'xkbcommon >= 1.11.0' ... has version '1.5.0'`

Also `libinput >= 1.29` (bookworm 1.22.1) and `libseat >= 0.8.0` (bookworm
0.7.0). All three built from source.

**Note the two different floors for libinput:** aquamarine asks for `>=1.26.0`,
Hyprland separately asks `>=1.29`. Build something recent (1.30.x), not the
minimum that satisfies the first thing that complains.

`pixman` needs **no** rebuild — aquamarine declares no floor and bookworm's
0.42.2 is fine.

---

## `None of the required 'lua55;lua5.5;...' found`

Hyprland pins Lua **`>=5.5,<5.6`**; Debian maxes at 5.4.4. Built from
lua.org, with **`MYCFLAGS=-fPIC`** — `liblua.a` is static and gets linked into
shared objects; without PIC you get a confusing Hyprland link error.

Upstream ships no `.pc` (its `pc:` make target only *prints* variables), so one
is written from `pkgconfig/lua5.5.pc.in`. **The filename must match** one of
Hyprland's candidates.

---

## `error: use of undeclared identifier 'CAIRO_FORMAT_RGB96F'`

Fails ~700 objects into the Hyprland compile. A float surface format added in
cairo **1.17.2**; bookworm has **1.16.0**. Hyprland declares bare `cairo` with
no floor.

Built cairo 1.18.4. No rebuild of hyprgraphics/hyprcursor needed — cairo holds
ABI compatibility across `libcairo.so.2`.

> **Pattern:** *under-declared version floors.* Upstreams that write
> `pkg_check_modules(... cairo)` with no minimum pass configure and fail at
> compile time. Cheap to fix, expensive to diagnose.

---

## `SyntaxError` in `meta/generateLuaStubs.py`

```
meta/generateLuaStubs.py:285: type ClassMember = str
                              ^^^^ SyntaxError
```

PEP 695 type-alias syntax, **new in Python 3.12**. Debian 12 ships **3.11**.
The build dies before compiling any C++.

The script only generates LuaLS editor stubs, and CMake offers no flag to skip
it — the target is `ALL` and both `Hyprland` and `hyprland_lib` depend on it.

`patches/hyprland-generateLuaStubs-pep695.patch` converts the five aliases to
plain assignments. Safe: PEP 695 aliases are lazily evaluated and plain
assignments eagerly, which differs only for forward references — and these five
refer only to builtins or to aliases defined above them.

---

## Three `.pc` files upstream does not ship

`tomlplusplus`, `re2` and `lua` all resolve through `.pc` files **Debian
authors downstream**. Upstream ships none.

> **"It's in Debian" tells you nothing about what upstream installs.**

Templates live in `pkgconfig/`. A from-scratch prefix rebuild must recreate
them or configure fails looking like a missing library.

`glslang` deliberately has no `.pc` at all — it is CMake-config only, found via
`CMAKE_PREFIX_PATH`. `pkg-config glslang` failing is **correct**.

---

## Hyprland config errors on 0.56

The wiki documents a different version. Several forms changed:

| Old | 0.56 |
|---|---|
| `dwindle:pseudotile` | **removed** |
| `togglesplit` dispatcher | `layoutmsg, togglesplit` |
| `windowrulev2` | `windowrule` |
| `layerrule = blur, launcher` | syntax changed |

Validate against the source you built rather than the wiki:

```bash
# options
grep -rhoE '"[a-z]+:[a-zA-Z:_0-9.]+"' src/config/values/ConfigValues.cpp | tr -d '"' | sort -u
# dispatchers
sed -n '42,140p' src/managers/KeybindManager.cpp | grep -oE '"[a-z0-9]+"' | tr -d '"' | sort -u
```

---

## fuzzel: `key/value pair has no value`

Debian 12 ships fuzzel **1.8.2** (2023); online docs describe 1.11+. Keys that
do **not** exist in 1.8.2: `tabs`, and the colors `placeholder`, `input`,
`counter`. There is also no `prompt` **color**.

```bash
man 5 fuzzel.ini | grep -oE '^       [a-z][a-z0-9_-]+' | sort -u
```

Also: `--password` does **not** work in dmenu mode, so a Wi-Fi passphrase
prompt has to go elsewhere (`network-menu.sh` hands it to `nmcli --ask` in a
terminal). `--log-level=error` silences the normal `info:` chatter.

---

## Testing: you cannot nest it

Covered in the README, repeated here because the error text is what people
search for:

```
libseat: Could not take control of session: Device or resource busy
wl_registry#2: error 0: invalid version for global wl_compositor (4): have 4, wanted 6
CBackend::create() failed!
```

Neither is a build defect. One logind session supports one compositor, and
aquamarine's nested backend needs `wl_compositor` v6 which sway 1.7 does not
advertise. Use a second VT (`Ctrl+Alt+F3`).

---

## Mesa: not the problem

Widely assumed to be too old. It is not:

```
Using: OpenGL ES 3.2 Mesa 22.3.6
Renderer: AMD Radeon Graphics (renoir, LLVM 15.0.6, DRM 3.49)
drm: Atomic supported, using atomic for modesetting
Created a GBM allocator with drm fd 32
```

Bookworm's Mesa 22.3.6 handles GBM, atomic modesetting and EGL/GLES 3.2.
**No Mesa rebuild required.**

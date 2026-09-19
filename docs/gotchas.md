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

## No X11 application ever opens (no error, nothing happens)

**The worst failure here, because it is completely silent.** Launch an X11 app
under a from-source Hyprland on Debian 12 and nothing appears. No crash, no
error, no log line — Hyprland's logs say nothing because `debug:disable_logs`
defaults to `true`. Affects everything on Xwayland: Electron apps that have not
been told to use Wayland, older GTK/Qt apps, VPN clients, `xeyes`.

The giveaway: the window exists on the X side but the compositor has no idea.

```bash
xeyes &
xwininfo -root -children | grep -i eyes     # IsViewable -- X has it
hyprctl clients | grep -i xeyes             # empty -- Hyprland does not
```

**Cause.** Debian 12 ships **Xwayland 22.1.9**, which predates
`xwayland-shell-v1` / `WL_SURFACE_SERIAL` (added in Xwayland 23.1) and still
uses the legacy `WL_SURFACE_ID` client message.

In `src/xwayland/XWM.cpp`, Hyprland's `WL_SURFACE_ID` branch associates the X
surface only if the `wl_surface` resource **already exists** at that moment. It
never records the id, so when the surface shows up a moment later,
`onNewSurface()` has nothing to match against and the association never
happens.

This is an upstream assumption (modern Xwayland always sends the serial), not a
build defect — but on bookworm it means X11 support is entirely broken.

**Fix** — `patches/hyprland-xwayland-wl-surface-id.patch`, applied
automatically by `build/05-hyprland.sh`:

```c
auto id       = e->data.data32[0];
+ XSURF->m_wlID = id;   // legacy WL_SURFACE_ID path (Xwayland < 23.1)
auto resource = wl_client_get_object(...);
```

One line. Harmless on Xwayland >= 23.1 — it sets a field the modern path does
not consult.

> **This patch lives in the working tree.** Re-cloning Hyprland or running
> `git checkout` on that file silently restores the bug, and the symptom is
> "X11 apps stopped opening" with nothing in any log.

**Alternatives if you would rather not patch:**
- Run Electron apps natively:
  `app --ozone-platform=wayland --enable-features=UseOzonePlatform`
  (verified working; persist it with a desktop-file override in
  `~/.local/share/applications/`)
- Build Xwayland >= 23.1 yourself — bookworm has no backport

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

## Screen sharing offers nothing (Discord, browsers, conferencing)

"Share screen" shows an empty list, or the dialog never appears. Screen capture
on Wayland goes through **xdg-desktop-portal** plus a compositor-specific
backend — without `xdg-desktop-portal-hyprland` there is nothing to capture
with. `build/09-xdph.sh` builds it; `./install-portal.sh` registers it.

Building it is the easy part. **Three things must line up:**

**1. systemd cannot see the unit.** It installs to
`/opt/hypr/lib/systemd/user`, which systemd does not scan. Symlink it into
`~/.config/systemd/user`.

**2. xdg-desktop-portal cannot find `hyprland.portal`.** Bookworm has xdp
**1.16**, which only scans `/usr/share/xdg-desktop-portal/portals` and has no
drop-in directory. A systemd service drop-in points `XDG_DESKTOP_PORTAL_DIR`
at a user directory instead.

> **`XDG_DESKTOP_PORTAL_DIR` replaces the search path — it does not add to
> it.** Point it at a directory containing only `hyprland.portal` and you lose
> the GTK portal, which means file-picker dialogs stop working everywhere.
> `install-portal.sh` symlinks the system `.portal` files in alongside.

**3. The Qt6 picker cannot be built here.** Upstream's
`hyprland-share-picker` is Qt6, and bookworm's Qt6 is **libstdc++** while this
prefix is **libc++** — the exact ABI mix that corrupts at runtime
([why-libcxx.md](why-libcxx.md)). So `-DBUILD_SHARE_PICKER=OFF`, and
`config/hypr/scripts/share-picker.sh` replaces it using fuzzel + slurp. It
speaks xdph's stdout protocol directly:

```
[SELECTION]{flags}/screen:<output>
[SELECTION]{flags}/window:<id>
[SELECTION]{flags}/region:<output>@<x>,<y>,<w>,<h>
```

It needs `jq`, and `fuzzel --index` — another reason the 1.12 build matters,
since Debian's 1.8.2 has no `--index`.

The service declares `ConditionEnvironment=WAYLAND_DISPLAY`, so it will not
start from a TTY or over SSH. That is correct, not a fault.

---

## Two patches live in the working tree

`patches/` holds both, and `build/05-hyprland.sh` applies them — but they are
**not** committed to the Hyprland checkout. A re-clone or a stray
`git checkout` on either file restores the original bug:

| Patch | Symptom if lost |
|---|---|
| `hyprland-xwayland-wl-surface-id.patch` | X11 apps silently never open |
| `hyprland-generateLuaStubs-pep695.patch` | build dies with a Python `SyntaxError` |

The build script re-applies both idempotently, so re-running it is the fix.

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

## Session dies instantly, bounces back to the login screen

The single most confusing failure here, because **nothing appears on screen**.

`/opt/hypr/share/wayland-sessions/hyprland.desktop` — installed by Hyprland
itself — has `Exec=/opt/hypr/bin/start-hyprland`. That path is absolute and
works, but `start-hyprland` then execs **`Hyprland` by name**.

A display manager does not give the session your login shell's PATH. GDM's is
`/usr/local/bin:/usr/bin:/bin`. `/opt/hypr/bin` is not in it, so the exec fails
(`execvp failed: No such file or directory` in the journal) and GDM returns to
the greeter with no visible error.

**Fix:** `./install-session.sh`, which installs a wrapper that sets PATH first:

```sh
export PATH="/opt/hypr/bin:$HOME/.local/bin:$PATH"
exec /opt/hypr/bin/start-hyprland "$@"
```

`~/.local/bin` is there too because `hypr-menu` is invoked by name from
`hyprland.conf` and from waybar `on-click` handlers.

It has to be a **separate script**, not an inline `Exec=`: the Desktop Entry
spec forbids unquoted `'`, `$` and `;` in `Exec`, and
`desktop-file-validate` rejects the inline form.

> This affects every display manager, not just GDM — the PATH is the issue,
> not GDM specifically.

---

## fuzzel: `key/value pair has no value`, or no mouse selection

Debian 12 ships fuzzel **1.8.2** (2023); online docs describe 1.11+. Two
separate problems:

**Keys that do not exist in 1.8.2**: `tabs`, `use-bold`, `placeholder`,
`match-mode`, and the colors `placeholder`, `input`, `counter`. There is also
no `prompt` **color**. Each is rejected outright at startup.

**No mouse selection in dmenu mode.** This is the one that matters for
`hypr-menu`: entries render, but cannot be clicked. Keyboard only.

`build/08-fuzzel.sh` builds **1.12.0**, which fixes both. Note it needs
`wayland-protocols >= 1.32` and bookworm has 1.31, so it must be built against
the prefix — not with system libraries.

Validate a config against the version you actually have:

```bash
grep -oE '^\\fB[a-z][a-z0-9_-]*\\fR$' /opt/hypr/share/man/man5/fuzzel.ini.5 \
  | sed 's/\\fB//;s/\\fR//' | sort -u
```

Also: `--password` does **not** work in dmenu mode, so a Wi-Fi passphrase
prompt has to go elsewhere (`network-menu.sh` hands it to `nmcli --ask` in a
terminal). `--log-level=error` silences the normal `info:` chatter.

**Watch for lost glyphs.** A Nerd Font glyph in `prompt=` that does not survive
however you write the file leaves whitespace, and fuzzel reports
`[main].prompt: key/value pair has no value`. Check with
`sed -n '/^prompt=/p' fuzzel.ini | od -c`.

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

# Hyprland on Debian 12 (bookworm)

Build **Hyprland 0.56.2**, **hyprlock** and **Waybar 0.15** from source on
Debian 12 — a distro whose default compiler cannot compile them.

```bash
git clone https://github.com/hariharanjpv/hyprland-for-debian12
cd hyprland-for-debian12
./build.sh
./install-config.sh
```

---

## Why this repo exists

Hyprland is **not packaged for Debian 12 at any version**. It appears only in
`trixie-backports`, `forky` and `sid`. And you cannot simply build it:

```
$ gcc --version
gcc (Debian 12.2.0-14+deb12u1) 12.2.0

$ ls /usr/include/c++/12/format
ls: cannot access '/usr/include/c++/12/format': No such file or directory
```

Hyprland needs `std::format`. GCC 12's standard library does not have it.
The usual advice is "bootstrap GCC 14" — roughly two hours and ~10 GB.

**You don't have to.** Debian 12 ships `clang-19` and `libc++-19` in `main`,
and libc++ 19 is fully C++23.

> A C++ toolchain is two separate things: the **compiler** (`clang`/`gcc`) and
> the **standard library** (`libc++`/`libstdc++`). They are swappable. The
> compiler was never the blocker — the standard library was.

That single substitution is what makes this tractable. Everything else in this
repo follows from it. See **[docs/why-libcxx.md](docs/why-libcxx.md)**.

---

## What gets built

| | Version | Prefix |
|---|---|---|
| Hyprland | 0.56.2 | `/opt/hypr` |
| hyprlock | 0.9.6 | `/opt/hypr` |
| Waybar | 0.15.0 | `/opt/waybar` |
| fuzzel | 1.12.0 | `/opt/hypr` |
| aquamarine, hyprutils, hyprlang, hyprcursor, hyprgraphics, hyprwire | see `versions.env` | `/opt/hypr` |
| wayland 1.26, wayland-protocols 1.49, libdrm 2.4.134, libxkbcommon 1.13.2, libinput 1.30.4, libseat 0.9.3, libei 1.6.0, cairo 1.18.4, libdisplay-info, xcb-util-errors | | `/opt/hypr` |
| glslang, re2, muparser, tomlplusplus, sdbus-c++, date, Lua 5.5 | | `/opt/hypr` |

**~26 source builds.** Budget 1–2 hours on a modern machine, plus ~6 GB.

Everything installs into **private prefixes**. Nothing overwrites a system
library, so your current desktop keeps working and remains your fallback the
whole way through.

---

## One thing you should know up front

Debian 12 ships **Xwayland 22.1.9**, too old for the protocol modern Hyprland
assumes. Without a patch, **no X11 application ever opens** — silently, with
nothing in any log. `build/05-hyprland.sh` applies a one-line fix
automatically; see [docs/gotchas.md](docs/gotchas.md#no-x11-application-ever-opens-no-error-nothing-happens)
for the mechanism.

## Requirements

- Debian 12 (bookworm), amd64
- `sudo` (for `apt`, and to create `/opt/hypr` — the build itself runs unprivileged)
- ~6 GB free disk
- A GPU with working KMS. Verified on **AMD Renoir with Mesa 22.3.6** —
  bookworm's Mesa is **sufficient**, no Mesa rebuild needed. Intel and older
  AMD should be fine; NVIDIA proprietary is untested.

---

## Usage

```bash
./build.sh              # everything, skipping what is already built
./build.sh --list       # show the steps
./build.sh 03 04        # only those steps
```

Every step is **idempotent** — a failed run resumes rather than starting over.
Pins live in **`versions.env`**; bump them there, not in the scripts.

### Testing without committing

You **cannot** test Hyprland nested inside sway or another older compositor.
Two independent blockers:

1. One logind session can only be controlled by one compositor →
   `libseat: Could not take control of session: Device or resource busy`
2. aquamarine's nested Wayland backend needs `wl_compositor` **v6**; sway 1.7
   (wlroots 0.15) advertises **v4** →
   `invalid version for global wl_compositor (4): have 4, wanted 6`

Instead, use a second VT — your current session stays alive on its own VT and
you can switch back at any time:

```
Ctrl+Alt+F3  ->  log in  ->  hypr
Ctrl+Alt+F2  ->  back to your old session
```

`hypr` is installed by `install-config.sh` and refuses to run inside an
existing graphical session rather than failing confusingly.

### Making it a login option

```bash
./install-session.sh
```

Hyprland then appears in your display manager's session picker.

**Do not simply copy `/opt/hypr/share/wayland-sessions/hyprland.desktop`.**
Its `Exec` is `start-hyprland`, which execs `Hyprland` **by name** — and a
display manager's session PATH (GDM's is `/usr/local/bin:/usr/bin:/bin`) does
not include `/opt/hypr/bin`. The session dies instantly and you bounce back to
the login screen with nothing on screen. `install-session.sh` installs a small
wrapper that fixes the PATH first.

---

## What's in `config/`

A working, minimal setup — not a full rice:

- **`hyprland.conf`** — every option and dispatcher validated against Hyprland
  0.56.2's own source, not against the wiki (which documents a different version)
- **`hyprlock.conf`**
- **`fuzzel.ini`** — launcher theme for **fuzzel 1.12**, built by
  `build/08-fuzzel.sh`. Debian's 1.8.2 is not enough: it has **no mouse
  selection in dmenu mode**, so every `hypr-menu` entry would be
  keyboard-only.
- **`bin/hypr-menu`** — nested Omarchy-style menus built on `fuzzel --dmenu`.
  The nesting lives in the script, not the launcher, so it is easy to extend.
- **`hypr/scripts/`** — wallpaper, lock, network, bluetooth, volume,
  brightness, keyboard layout, power profile, night light. No sway
  dependencies.

Desktop services come from apt, not source: **`libnotify-bin`** (`notify-send`),
**`sway-notification-center`** (the daemon those notifications reach — the
package is *not* called `swaync`), and **`wlsunset`** for night light. The
scripts still guard every `notify-send` call with `command -v`, so they degrade
quietly rather than erroring if you skip them.

`install-config.sh` backs up anything it would overwrite.

---

## Documentation

| | |
|---|---|
| **[docs/why-libcxx.md](docs/why-libcxx.md)** | The core idea, and the ABI rule it forces on every C++ dependency |
| **[docs/gotchas.md](docs/gotchas.md)** | Every wall hit, with the error text — start here if a build failed |
| **[docs/troubleshooting.md](docs/troubleshooting.md)** | Runtime problems after a successful build |

---

## Status & honesty

These scripts were **reconstructed from a verified manual build** on one
machine. Every version, flag and patch here is what actually produced a working
Hyprland — but the scripts have **not yet been run end-to-end on a clean
Debian 12 install**. If you hit something, please open an issue with the step
number and the first error (not the last — with CMake the root cause is at the
top).

Independent confirmations on other hardware are especially welcome.

## Licence

MIT. The software this builds carries its own licences.

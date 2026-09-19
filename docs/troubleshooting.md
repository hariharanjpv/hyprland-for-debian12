# Troubleshooting

Runtime problems *after* a successful build. For build failures see
[gotchas.md](gotchas.md).

---

## Hyprland exits immediately

Read the log — stdout logging is off by default:

```bash
tail -60 "$(ls -t /run/user/$UID/hypr/*/hyprland.log | head -1)"
```

`~/.local/bin/hypr` also tees to `~/hypr-last-session.log`, which survives the
session ending (the `/run` one does not survive a reboot).

Enable stdout logs with `debug:disable_logs = false` in `hyprland.conf`.

---

## `Device or resource busy` / `wl_compositor (4) ... wanted 6`

You launched it from inside an existing graphical session. Hyprland needs its
own logind session: `Ctrl+Alt+F3`, log in, run `hypr`. See
[gotchas.md](gotchas.md#testing-you-cannot-nest-it).

---

## Picked Hyprland at the login screen, got dumped straight back

The session is exiting immediately. Almost always PATH: the `.desktop` `Exec`
resolves, but `start-hyprland` execs `Hyprland` **by name** and a display
manager's PATH does not include `/opt/hypr/bin`.

```bash
journalctl -b -n 100 | grep -iE 'hyprland|execvp|session'
cat /usr/share/wayland-sessions/hyprland.desktop     # Exec should be
                                                     # /usr/local/bin/hyprland-session
```

Fix with `./install-session.sh`. See
[gotchas.md](gotchas.md#session-dies-instantly-bounces-back-to-the-login-screen).

---

## An X11 app does not open and says nothing

Check whether X has the window but the compositor does not:

```bash
xeyes &
hyprctl clients | grep -ci xwayland     # 0 means none are mapped
```

If zero, the XWM patch is missing — see
[gotchas.md](gotchas.md#no-x11-application-ever-opens-no-error-nothing-happens).
Confirm and re-apply:

```bash
grep -c 'XSURF->m_wlID = id;' ~/hyprland-build/src/Hyprland/src/xwayland/XWM.cpp
./build.sh 05    # re-applies and rebuilds
```

**The rebuilt binary only takes effect after you log out and back in** — an
already-running Hyprland keeps the old code.

---

## A library resolves to the wrong place

Everything built here should resolve inside its prefix:

```bash
ldd /opt/hypr/bin/Hyprland | grep -E 'wayland|hypr|aquamarine|seat|input'
```

If `libwayland-server.so.0` comes back from `/usr/local/...` or `/usr/lib/...`,
the rpath is not winning. Two causes:

- A **stray newer wayland in `/usr/local`** from some earlier source build.
  `/usr/local/lib/x86_64-linux-gnu` is in `ld.so.conf.d` and **outranks
  `/usr/lib`**. Check with `ldconfig -p | grep wayland`. Harmless to leave as
  long as the rpath wins for Hyprland's own process.
- A build that was configured without `LDFLAGS` set. Rebuild that component
  with `env.sh` sourced.

`-Wl,-rpath` emits **DT_RUNPATH**, which — unlike legacy DT_RPATH — is *not*
inherited by transitive dependencies. `LD_LIBRARY_PATH` **is**. That is why
`env.sh` sets both; they cover different cases.

---

## Stale headers from `/usr/local/include`

`/usr/local/include` sits **above** `/usr/include` in clang's default search:

```
/usr/lib/llvm-19/lib/clang/19/include
/usr/local/include          <-- stale headers here win
/usr/include/x86_64-linux-gnu
/usr/include
```

Explicit `-I` from `pkg-config` beats all default dirs, so correct builds are
safe — but a build that skips pkg-config can silently compile against old
headers while linking new libraries. **Suspect this first** on odd wayland
struct or symbol errors.

---

## `xkbcommon: ERROR: .../iso8859-1/Compose: not a valid UTF-8 string`

Your locale is not UTF-8, so xkbcommon picks a Latin-1 Compose file and then
reads it as UTF-8. Only consequence: **dead keys do not work.**

```bash
localectl status
sudo localectl set-locale LANG=en_US.UTF-8   # then log out and back in
```

---

## No bar

Waybar is started by absolute path because `/opt/waybar/bin` is not on `PATH`:

```
exec-once = /opt/waybar/bin/waybar
```

`hyprctl reload` re-reads the config but does **not** re-run `exec-once` — start
it by hand that once, or use `hypr-menu` → System → Toggle Waybar.

---

## hyprlock will not unlock

hyprlock authenticates through PAM. Check `/etc/pam.d/hyprlock` exists and
includes `common-auth`. If it is missing:

```bash
printf 'auth include common-auth\naccount include common-account\n' \
  | sudo tee /etc/pam.d/hyprlock
```

**Test hyprlock before binding it to anything** — from a terminal, where you
can kill it from another VT if it misbehaves.

---

## Screen sharing does not work

`xdg-desktop-portal-hyprland` is not built by these scripts. Without it,
screencasting from browsers and conferencing apps will not work. It needs
`sdbus-c++` (already in `/opt/hypr`) plus `pipewire`, and is a reasonable
addition if you need it.

---

## Rolling it all back

```bash
sudo rm -rf /opt/hypr /opt/waybar
sudo rm -f /usr/share/wayland-sessions/hyprland.desktop
sudo rm -f /usr/local/bin/hyprland-session
rm -rf ~/.config/hypr ~/.config/fuzzel ~/.local/bin/hypr ~/.local/bin/hypr-menu
```

To see which apt packages were added, snapshot **before** you start:

```bash
apt-mark showmanual | sort > ~/pkgs-before.txt
# ... later ...
comm -13 ~/pkgs-before.txt <(apt-mark showmanual | sort)
```

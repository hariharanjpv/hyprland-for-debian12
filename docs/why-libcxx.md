# Why clang + libc++, and the rule it forces

## The blocker is not the compiler

```
$ gcc --version
gcc (Debian 12.2.0-14+deb12u1) 12.2.0

$ ls /usr/include/c++/12/expected   # exists
$ ls /usr/include/c++/12/format     # DOES NOT EXIST
```

Hyprland uses `std::format` heavily. libstdc++-12 does not provide it. The
common conclusion is "bookworm's GCC is too old, bootstrap GCC 14" — about two
hours of compiling and ~10 GB.

That conclusion confuses two separate things:

| | Examples |
|---|---|
| **Compiler** | `gcc`, `clang` |
| **Standard library** | `libstdc++` (GNU), `libc++` (LLVM) |

They are swappable. Debian 12 ships **`clang-19`** and **`libc++-19-dev`** in
`main`, and libc++ 19 implements C++23 in full. Verify it yourself:

```bash
sudo apt install clang-19 libc++-19-dev libc++abi-19-dev
printf '#include <format>\n#include <expected>\n#include <print>\nint main(){ std::print("{}\\n", std::format("{}-{}", 42, "ok")); }' \
  | clang++-19 -stdlib=libc++ -std=c++23 -x c++ - -o /tmp/t && /tmp/t
# -> 42-ok
```

No GCC bootstrap. `01-toolchain.sh` runs exactly this check and aborts if it fails.

## The cost: one ABI rule

**libc++ and libstdc++ cannot be mixed in a single process.** `std::string`
has a different memory layout in each. Mixing links cleanly and then corrupts
at runtime wherever a `std::` type crosses the boundary — the worst class of
bug to debug.

Debian's C++ shared libraries are all libstdc++-built:

```
libtomlplusplus.so.3.3.0  -> libstdc++.so.6
libre2.so.9               -> libstdc++.so.6
libglslang.so.12          -> libstdc++.so.6
```

So **every C++ dependency in the chain must be rebuilt with libc++**:

| Dependency | Why it cannot come from apt |
|---|---|
| **glslang** | `glslang::TShader`, `std::string` in and out |
| **re2** | API saturated with `std::string` / `std::string_view` |
| **muparser** | C++ API |
| **tomlplusplus** | `std::string`/`string_view`/`optional` everywhere → solved by going **header-only** (`TOML_HEADER_ONLY=1`), which removes the boundary entirely |
| **sdbus-c++** | C++ API; also absent from bookworm |

**C libraries are unaffected** — C has no name mangling or templates, so
`wayland`, `libdrm`, `pixman`, `cairo`, `libinput`, `librsvg`, `libzip`,
`libmagic` can come from apt or be built with either compiler.

### The one tolerated exception

`hyprwayland-scanner` links Debian's `libpugixml` (libstdc++) alongside libc++.
It works because pugixml's API is `char_t*`-based — almost no `std::` types
cross — and it is a build-time code generator, not part of the compositor.
Noted here so it is a known exception rather than an oversight.

## Auditing it correctly

Use **`objdump`**, not `ldd`:

```bash
objdump -p <lib> | grep NEEDED   # DIRECT dependencies  <-- correct
ldd <lib>                        # full transitive closure <-- false positives
```

An `ldd`-based check will report `libstdc++` for `libhyprcursor` and
`libhyprgraphics` and look alarming. It is wrong: neither has a *direct*
dependency on it. libstdc++ enters far down the gdk-pixbuf/rsvg closure where
no `std::` type ever reaches our code. `build/lib.sh`'s `assert_libcxx()` uses
`objdump` for this reason.

## Waybar is the deliberate exception

Waybar is built with the **default gcc/libstdc++ toolchain**, into a separate
prefix (`/opt/waybar`). It is a GTK3 application — gtkmm, spdlog, fmt and
jsoncpp are all libstdc++. Building it with libc++ would mix ABIs against
gtkmm. Separate prefix, separate toolchain, no contact.

## Generalising

Nothing here is Hyprland-specific. Any modern C++ project that "needs a newer
GCC than bookworm has" is worth trying with clang-19 + libc++ first. The price
is always the same: rebuild the C++ dependencies, leave the C ones alone.

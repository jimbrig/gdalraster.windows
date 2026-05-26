# 07 - archived local working-state evidence

> [!IMPORTANT]
> This is an archive note tied to one local machine context.
> It is useful for historical debugging, but it is not normative project
> guidance.

This document reconstructs the known-good Windows state from concrete evidence only.

## evidence policy

included as authoritative:
- command/history logs under `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/`
- actual local files and environment state on this machine
- human-authored issue summary and maintainer response:
  - [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
  - [ctoney comment on #982](https://github.com/firelab/gdalraster/issues/982#issuecomment-4526009197)

used as context only (not source of truth):
- AI-generated explanations in chat transcripts
- AI-generated runbooks

## concrete artifacts

- custom runtime binary present at:
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/bin/libgdal-39.dll`
- command logs:
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/msys2-ucrt64-shell-history.txt`
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/cmake-gdal-build-UCRT64.txt`
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/jimmy@DESKTOP-MSI UCRT64 tmpgdal.txt`
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/pacman -Qi mingw-w64-ucrt-x86_64-.txt`
  - `dev/temp/GDAL-GDALRASTER-RTOOLS45/reference/pacman -S mingw-w64-ucrt-x86_64-g.txt`

## reconstructed sequence (from command evidence)

1. Update MSYS2 UCRT64 package state with `pacman -Syu` (multiple times).
2. Install/refresh UCRT64 toolchain and GDAL dependency universe with pacman.
3. Clone GDAL v3.13.0 source in `/tmp/gdal`.
4. Configure GDAL with CMake (Ninja, UCRT64 prefix/toolchain paths).
5. Retry configure/build with linker flag hardening until successful:
   - `-Wl,--kill-at`
   - `-Wl,--no-undefined`
   - `-DGDAL_HIDE_INTERNAL_SYMBOLS=ON`
6. Build/install into custom prefix `C:/gdal-ucrt64`.
7. Build `gdalraster` from source via:
   - `R CMD INSTALL . --no-test-load`
8. Use `ntldd -R` diagnostics for DLL dependency inspection.

Source evidence:
- `msys2-ucrt64-shell-history.txt` shows exact command progression including failed/retried CMake invocations and `R CMD INSTALL --no-test-load`.
- `cmake-gdal-build-UCRT64.txt` and `jimmy@DESKTOP-MSI UCRT64 tmpgdal.txt` show configured/located dependencies and enabled GDAL features.

## known build-time configuration

from `~/.R/Makevars.win` on this machine:

```makefile
GDAL_HOME=C:/gdal-ucrt64
PKG_CPPFLAGS = -I$(GDAL_HOME)/include
PKG_LIBS = -L$(GDAL_HOME)/lib -lgdal
```

observed implications:
- `gdalraster` source compilation links to `C:/gdal-ucrt64/lib`.
- compile-time include path is `C:/gdal-ucrt64/include`.

## known runtime setup

current observed state:
- `C:/gdal-ucrt64/bin` exists and contains `libgdal-39.dll` and GDAL executables.
- `C:/rtools45/ucrt64/bin` exists with a large DLL set.
- `gdalinfo` works when `PATH` includes both:
  - `C:/gdal-ucrt64/bin`
  - `C:/rtools45/ucrt64/bin`

verified command:

```powershell
$env:PATH='C:/gdal-ucrt64/bin;C:/rtools45/ucrt64/bin;' + $env:PATH
& 'C:/gdal-ucrt64/bin/gdalinfo.exe' --version
```

observed output:
- `GDAL 3.13.0 "Iowa City", released 2026/05/04`

## installed R package state (current local)

observed via local R:
- R library path includes:
  - `C:/Users/jimmy/AppData/Local/R/win-library/4.6`
- installed `gdalraster`:
  - version `2.6.1.9000`
  - path `C:/Users/jimmy/AppData/Local/R/win-library/4.6/gdalraster`
- `gdalraster` namespace `.onLoad` sets `GDAL_DATA`/`PROJ_LIB` to package-local data dirs when present.

observed runtime result in current environment:
- `gdalraster::gdal_global_reg_names()` returns non-empty (length 8).

## package-manager evidence about baseline GDAL

`pacman -Qi mingw-w64-ucrt-x86_64-gdal` log (captured in reference) shows a baseline package state where optional deps did not explicitly include `muparser` in metadata at that time.

later upgrade/install logs show broader dependency set and newer package versions.

interpretation:
- baseline package state and feature exposure changed over time.
- your working path explicitly avoided relying on that baseline by building custom GDAL to `C:/gdal-ucrt64`.

## human summary alignment

your issue summary in [#982](https://github.com/firelab/gdalraster/issues/982) matches this evidence pattern:
- custom GDAL 3.13 build in UCRT64
- `Makevars.win` pointing to `C:/gdal-ucrt64`
- source install of `gdalraster` with `--no-test-load`
- runtime PATH/DLL handling to ensure loadability
- non-empty Algorithm API registry

maintainer response context in [comment](https://github.com/firelab/gdalraster/issues/982#issuecomment-4526009197) should be read as guidance on upstream interpretation and next steps, not as replacement for local command evidence.

## startup file mapping (resolved)

Startup behavior is represented in this repo and local config as follows:

- project-level startup hook in `.Rprofile` (loads project `.Renviron` when present)
- project `.Renviron` (currently empty in repo snapshot, but explicitly part of startup chain)
- user build config in `~/.R/Makevars.win` (captured and consistent with the working setup)

The prior `~/.config/R/*` wording in issue/chats reflects path-style differences in user configuration, not a missing configuration concept.

## practical conclusion

The known-good result was achieved by a two-layer contract:

1. compile-time contract:
   - build/link `gdalraster` against custom GDAL at `C:/gdal-ucrt64`
2. runtime contract:
   - ensure Windows loader can resolve `libgdal-39.dll` and transitive DLLs (notably via PATH including both custom GDAL and UCRT64 runtime bins)

That contract is the key behavior to preserve in CI artifact design and in `gdalraster.windows` helper APIs.

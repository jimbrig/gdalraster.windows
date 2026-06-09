# gdalraster.windows

> \[!NOTE\] Self-contained [GDAL](https://gdal.org/) runtime tooling for
> Windows.

`gdalraster.windows` is an R package with companion CI scripts that
build and publish a Windows GDAL runtime bundle.

The package helps you:

- install that runtime locally
- build `gdalraster` from source against it
- load and verify `gdalraster` in a Windows session

By default, installs are isolated under package-managed user
directories.

Latest GDAL runtime release:
[gdal-v3.13.0](https://github.com/jimbrig/gdalraster.windows/releases/tag/gdal-v3.13.0)

## Installation

``` r

pak::pak("jimbrig/gdalraster.windows")
```

## Quick Start

``` r

# 1) install runtime bundle (defaults to latest release asset)
gdalraster.windows::install_gdal_runtime()

# 2) build gdalraster from source against that runtime
gdalraster.windows::install_gdalraster()

# 3) load and verify
library(gdalraster.windows)
gdalraster::gdal_global_reg_names()
```

## Offline / Air-Gapped Installation

[`install_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdal_runtime.md)
downloads the runtime bundle from GitHub Releases by default. On
machines without network access (or to pin an exact asset), pass a local
zip directly:

``` r

# 1) download the release asset on a connected machine:
#    https://github.com/jimbrig/gdalraster.windows/releases
# 2) transfer to the target machine
# 3) install from the local zip
gdalraster.windows::install_gdal_runtime(
  local_zip = "C:/Downloads/gdal-ucrt64-v3.13.0-windows-x64.zip"
)
```

A `fallback_zip` argument is also supported: when a release download
fails and a fallback zip exists, it is installed instead.

## Common Flows

If runtime and custom `gdalraster` install are already present:

``` r

library(gdalraster.windows)
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

Explicit load flow is also supported:

``` r

gdalraster.windows::load_gdal_dll()
gdalraster.windows::load_gdalraster()
gdalraster::gdal_global_reg_names()
```

Runtime verification helper:

``` r

gdalraster.windows::verify_gdalraster_runtime()
```

## What This Repository Contains

- An R helper package (`gdalraster.windows`)
- A Windows CI build pipeline for GDAL (`.github/workflows/build.yml`)
- Build and bundle scripts:
  - `tools/build_gdal.sh`
  - `tools/collect_dlls.sh`

The package and build scripts are designed to work together.

## Optional startup hook (`.Rprofile`)

``` r

# writes a managed hook block that loads the GDAL DLL and prepends
# the custom gdalraster library path at session startup
gdalraster.windows::add_gdal_rprofile_hook()
```

## Why This Exists

This repository started from practical Windows failures where
[`gdalraster::gdal_global_reg_names()`](https://firelab.github.io/gdalraster/reference/gdal_cli.html)
could be empty under some toolchain states. It now provides a maintained
runtime path that is isolated by default.

## Technical Architecture

This section is the technical rationale for the current design.

### 1) Root problem: static registration + MXE/static builds

GDAL’s Algorithm API uses static C++ registration. Under some Windows
build states (notably specific Rtools/MXE combinations), the top-level
algorithm registry has been observed to load but return no names. In
practice this means
[`gdalraster::gdal_global_reg_names()`](https://firelab.github.io/gdalraster/reference/gdal_cli.html)
can return `character(0)` even when GDAL is present.

This project solves that by controlling both the GDAL build profile and
runtime loading path, then rebuilding `gdalraster` against that known
runtime.

### 2) Toolchain stack in plain terms

- **MinGW-w64**: GCC-based Windows compiler toolchain for native
  `.exe`/`.dll`.
- **MSYS2**: package manager + shell environment used to assemble
  toolchains and dependencies (`pacman`).
- **UCRT64**: MSYS2 toolchain target using Microsoft’s Universal CRT.
- **Rtools45**: Windows R package build toolchain, also UCRT-based.

The practical requirement is to keep compile/runtime toolchains
compatible (MinGW/UCRT alignment) to avoid C/C++ runtime and ABI
mismatch problems.

### 3) Static vs dynamic linking in this repository

- Some runtime pieces are linked statically (for portability of GCC
  runtime bits).
- GDAL itself is delivered as a shared runtime DLL (`libgdal-*.dll`)
  with transitive dependencies bundled alongside it.

In other words: this project is not “single-file static GDAL”, it is a
self-contained runtime bundle with controlled dependency closure.

### 4) C++ ABI compatibility (why source rebuild is required)

`gdalraster` binds to GDAL C++ APIs via compiled code. Even when headers
match, ABI mismatches can break at runtime if binaries are built with
incompatible compiler/runtime combinations.

That is why this package installs `gdalraster` from source against the
bundled GDAL headers/import libs rather than assuming an arbitrary
prebuilt binary is compatible.

### 5) Key CMake/linker flags used and why

Current build uses flags in `tools/build_gdal.sh`, including:

- `-DGDAL_USE_MUPARSER=ON` for muparser-enabled algorithm functionality
- `-DGDAL_HIDE_INTERNAL_SYMBOLS=ON` to reduce export-surface pressure on
  Windows
- `-Wl,--kill-at` for Windows/MinGW export naming behavior
- `-static-libgcc -static-libstdc++` and static `winpthread` handling to
  reduce external runtime fragility

These flags are practical stability choices from observed Windows
build/runtime behavior, not arbitrary tuning.

### 6) Why `collect_dlls.sh` is essential

Building `libgdal-*.dll` is not sufficient by itself. Runtime success
depends on all non-Windows transitive DLL dependencies being present.

`tools/collect_dlls.sh` performs recursive dependency inspection
(`ntldd -R`), copies required UCRT64 DLLs into the bundle, and fails
when unresolved external non-Windows dependencies remain.

### 7) Windows DLL load order and preloading

Compile-time link success does not guarantee runtime load success.
Windows still needs to resolve `libgdal-*.dll` and its dependency tree
in the active process.

[`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
addresses this by:

- prepending bundle `bin/` to `PATH`
- setting GDAL/PROJ data env vars
- prepending bundle `python/` to `PYTHONPATH` (see section 9)
- optionally preloading `libgdal-*.dll` with
  `dyn.load(..., local = FALSE, now = TRUE)`

This is why explicit runtime activation exists in addition to source
builds.

### 8) GDAL/PROJ data directories

GDAL and PROJ require runtime data files (`share/gdal`, `share/proj`).
Without these, CRS and related functionality can fail even when DLL
loading succeeds.

[`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
sets:

- `GDAL_DATA`
- `PROJ_LIB`
- `PROJ_DATA`

from the installed bundle when available.

### 9) Embedded Python utilities (`osgeo_utils`)

Some GDAL CLI algorithms are implemented in Python rather than C++. For
example, `gdal driver gpkg validate` is a thin C++ entry point in
`libgdal` that embeds a CPython interpreter at runtime: GDAL locates a
`python.exe` on `PATH`, dynamically loads the matching `libpython` DLL,
calls `Py_Initialize()`, and imports
`osgeo_utils.samples.validate_gpkg`.

`osgeo_utils` is the pure-Python package shipped by GDAL’s `gdal-utils`
distribution (`swig/python/gdal-utils/` in the GDAL source tree).
Because it contains no compiled extension modules, it has no CPython ABI
coupling — any embedded interpreter version can import it.

The runtime bundle ships this package under `python/osgeo_utils`,
version-locked to the built GDAL tag.
[`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
prepends `<gdal_home>/python` to `PYTHONPATH` (session-scoped; never
persisted to user or machine environment) so the embedded interpreter
can resolve it. `PYTHONPATH` is read at `Py_Initialize()`, which
`libgdal` triggers lazily on first use of an embedded-python algorithm,
so activation-time configuration is early enough.

Without this, such algorithms fail with:

``` text
GDAL FAILURE 1: ... ModuleNotFoundError: No module named 'osgeo_utils'
```

Note: the compiled `osgeo` SWIG bindings (`from osgeo import gdal`) are
intentionally **not** built or bundled (`BUILD_PYTHON_BINDINGS` stays
off — no Python/SWIG in the build environment). They would pin the
bundle to a single CPython version/ABI. The Python-implemented
validators degrade gracefully without them (e.g. `validate_gpkg` skips
only tiled gridded coverage checks).

### 10) Compile-time paths vs runtime paths

These are separate concerns:

- **Compile-time**: headers/libs via Makevars (`PKG_CPPFLAGS`,
  `PKG_LIBS`)
- **Runtime**: DLL resolution via process environment and loader state

This package scopes compile-time settings to install calls (`withr`),
then manages runtime activation separately for session reliability.

### 11) Optional `.Rprofile` startup hook

For users who want persistence,
[`add_gdal_rprofile_hook()`](https://docs.jimbrig.com/gdalraster.windows/reference/add_gdal_rprofile_hook.md)
writes a managed startup block that can load runtime context early in
each session.

This is optional by design; default behavior stays non-destructive and
local.

## Upstream Context

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826)
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858)
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)
- [Rtools45
  news](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html)

## Package Guide

- [`vignettes/runtime-guide.Rmd`](https://docs.jimbrig.com/gdalraster.windows/vignettes/runtime-guide.Rmd)

## Testing

Run fast tests:

``` r

testthat::test_dir("tests/testthat")
```

Run clean-room isolation checks:

``` r

testthat::test_file("tests/testthat/test-e2e-clean-room.R")
```

Run full end-to-end clean-room flow (opt-in):

``` powershell
$env:GDALRASTER_WINDOWS_RUN_E2E="true"
Rscript -e "testthat::test_file('tests/testthat/test-e2e-clean-room.R')"
```

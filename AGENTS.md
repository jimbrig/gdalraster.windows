# AGENTS.md

## primary outcome

Provide a reliable Windows workflow for using `gdalraster` against a
self-contained GDAL runtime built in CI.

Primary user flow:

``` r

pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::install_gdal_runtime()
gdalraster.windows::install_gdalraster()
gdalraster.windows::load_gdalraster()
gdalraster::gdal_global_reg_names()
```

Auto-bootstrap flow (when runtime and source-built `gdalraster` are
already installed):

``` r

library(gdalraster.windows)
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

Also support explicit runtime activation:

``` r

gdalraster.windows::load_gdal_dll()
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

## required system behavior

1.  Build modern GDAL (currently 3.13+) from source in Windows CI using
    MSYS2 UCRT64 / Rtools45-compatible MinGW toolchain.
2.  Build with required features for this project, including `muparser`,
    and keep runtime self-contained.
3.  Produce a standalone GDAL runtime bundle archive with:
    - a top-level GDAL runtime DLL (`libgdal-*.dll`)
    - all required non-Windows dependent DLLs
    - required runtime data directories (`share/gdal`, `share/proj`)
    - pure-python GDAL utilities (`python/osgeo_utils`) for
      embedded-python algorithms (e.g. `gdal driver gpkg validate`)
4.  Build `gdalraster` from source against that bundled GDAL runtime.
5.  Ensure runtime loading is configured so `gdalraster` resolves
    bundled DLL dependencies at runtime (without relying on a matching
    user-installed Rtools environment), and so GDAL’s embedded python
    can import bundled `osgeo_utils` (session-scoped `PYTHONPATH`).
6.  Verify success with
    [`gdalraster::gdal_global_reg_names()`](https://firelab.github.io/gdalraster/reference/gdal_cli.html)
    returning non-empty output and the `driver gpkg validate` algorithm
    running end-to-end.
7.  Keep installs non-destructive by default:
    - runtime installs under package-managed user data paths
    - source builds target an isolated library path unless explicitly
      overridden

## responsibility split

- CI’s only responsibility is the GDAL runtime bundle: build, verify the
  bundle contract, and publish durable artifacts (workflow artifact +
  release asset).
- Building `gdalraster` against the bundle is package functionality
  ([`install_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdalraster.md)
  with scoped Makevars via `withr`), exercised on user machines and by
  package tests — never reimplemented inside CI.

## source of truth

- CI workflow and scripts are authoritative for build/release behavior:
  - [`.github/workflows/build.yml`](https://docs.jimbrig.com/gdalraster.windows/.github/workflows/build.yml)
  - [`tools/build_gdal.sh`](https://docs.jimbrig.com/gdalraster.windows/tools/build_gdal.sh)
  - [`tools/collect_dlls.sh`](https://docs.jimbrig.com/gdalraster.windows/tools/collect_dlls.sh)

## R package implementation constraints

- use modern package-style R with explicit namespacing.
- use `cli` for user-facing messaging and
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  for errors.
- use
  [`rlang::caller_env()`](https://rlang.r-lib.org/reference/stack.html)
  and
  [`rlang::caller_arg()`](https://rlang.r-lib.org/reference/caller_arg.html)
  in validators/errors.
- use `withr` for scoped state (`with_makevars`, env vars, lib paths);
  avoid leaking persistent session/user config.
- default source-install target for `gdalraster` must be non-destructive
  (isolated library path), not overwrite existing user/global installs
  unless explicitly requested.
- keep docs implementation-anchored and general; avoid session-specific
  claims.

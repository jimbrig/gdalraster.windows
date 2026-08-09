# AGENTS.md

## primary outcome

Provide a reliable Windows workflow for building a self-contained
`gdalraster` package against the GDAL runtime produced by this
repository.

Primary user flow:

``` r

pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::gdal_setup(user_lib = TRUE)

# every later session
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

The non-destructive setup default uses an isolated package-managed
library. Users opt into replacement in `.libPaths()[1]` with
`user_lib = TRUE`.

## required system behavior

1.  Build modern GDAL from source in Windows CI using the MSYS2 UCRT64 /
    Rtools-compatible MinGW toolchain.
2.  Build required features, including `muparser`, and keep the runtime
    self-contained.
3.  Publish a standalone GDAL SDK bundle containing:
    - a top-level GDAL runtime DLL;
    - all required non-Windows dependency DLLs;
    - headers and import libraries;
    - `share/gdal` and `share/proj`; and
    - `python/osgeo_utils`.
4.  Install and stamp the SDK idempotently.
5.  Build `gdalraster` from source against the SDK with scoped Makevars.
6.  Vendor the DLL closure, data, and Python utilities into the
    installed `gdalraster` package.
7.  Use a managed system-CPython `.pth` for embedded-Python algorithms;
    never persist or export `PYTHONPATH`.
8.  Verify in fresh processes that the Algorithm API, required drivers,
    first Parquet open, CRS support, and GeoPackage validator work.
9.  Keep installs non-destructive by default.

## responsibility split

- The build workflow and scripts own only the GDAL bundle:
  `.github/workflows/build.yml`, `tools/build_gdal.sh`, and
  `tools/collect_dlls.sh`.
- The R package owns runtime installation, provenance, source
  compilation, vendoring, Python provisioning,
  setup/update/status/uninstall, and fresh-process verification.
- `.github/workflows/e2e.yml` consumes exported package functions on a
  clean Windows runner and proves plain
  [`library(gdalraster)`](https://firelab.github.io/gdalraster/) in a
  new session.
- `.github/workflows/edge-cases.yml` constructs adversarial machine
  states and checks isolation and failure behavior.

## package architecture

The managed GDAL runtime is a build-time SDK. Runtime files are copied
into the installed `gdalraster` package:

- `libs/x64`: `gdalraster.dll`, `libgdal-*.dll`, and dependencies;
- `gdal` and `proj`: matching runtime data;
- `python`: pure-Python `osgeo_utils`; and
- `gdalraster.windows-build.dcf`: build provenance.

There is no runtime activation API, auto-bootstrap, `.Rprofile` hook,
`PATH` mutation, DLL preload, or GDAL/PROJ/Python environment export.

## R implementation constraints

- Use modern package-style R with explicit namespacing.
- Use `cli` for user-facing messages and
  [`cli::cli_abort()`](https://cli.r-lib.org/reference/cli_abort.html)
  for errors.
- Use
  [`rlang::caller_env()`](https://rlang.r-lib.org/reference/stack.html)
  and
  [`rlang::caller_arg()`](https://rlang.r-lib.org/reference/caller_arg.html)
  in validators.
- Use `withr` for scoped state.
- Stage complete package replacements before changing an installed
  package.
- Preserve the isolated library as the default build destination.
- Never add Parquet initialization or session-order workarounds;
  Arrow/TLS correctness belongs to the bundle build.

## documentation hierarchy

Canonical user-facing behavior lives in `vignettes/`, roxygen help, and
the README. `dev/docs/` is non-normative scratch context and may lag
code.

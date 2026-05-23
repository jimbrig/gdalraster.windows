# 06 - r api contract draft

This file defines the proposed R API contract for `gdalraster.windows` before implementation changes.

status: draft, requires explicit approval before code changes in `R/`.

## goals

- keep CI as source of truth for runtime artifacts
- provide an explicit, safe R workflow for runtime install, activation, source build, and verification
- avoid destructive defaults (do not overwrite existing global `gdalraster` installs)
- enforce modern R package patterns (`withr`, `cli`, `rlang`)

## proposed exported functions

```r
gdal_home() -> character(1)
```

```r
configure_gdal_home(
  path,
  mode = c("option", "env")
) -> invisible(character(1))
```

```r
install_gdal_runtime(
  repo = "jimbrig/gdalraster.windows",
  tag = "latest",
  asset_pattern = "gdal-ucrt64-.*-windows-x64\\.zip$",
  gdal_home = gdal_home(),
  overwrite = FALSE,
  timeout_sec = 600
) -> invisible(character(1))
```

```r
activate_gdal_runtime(
  gdal_home = gdal_home(),
  preload = TRUE,
  set_env = TRUE,
  prepend_path = TRUE,
  quiet = FALSE
) -> invisible(list)
```

```r
install_gdalraster_source(
  lib = file.path(tools::R_user_dir("gdalraster.windows", "data"), "rlib"),
  source = c("cran", "github"),
  github_repo = "firelab/gdalraster",
  ref = "HEAD",
  upgrade = FALSE,
  reinstall = FALSE,
  configure_runtime = TRUE,
  gdal_home = gdal_home(),
  keep_makevars = FALSE,
  quiet = FALSE
) -> invisible(list)
```

```r
verify_gdalraster_runtime(
  lib = file.path(tools::R_user_dir("gdalraster.windows", "data"), "rlib"),
  activate_runtime = TRUE,
  gdal_home = gdal_home(),
  require_algorithms = TRUE
) -> invisible(list)
```

```r
bootstrap_gdalraster(
  repo = "jimbrig/gdalraster.windows",
  tag = "latest",
  lib = file.path(tools::R_user_dir("gdalraster.windows", "data"), "rlib"),
  source = c("cran", "github"),
  github_repo = "firelab/gdalraster",
  ref = "HEAD",
  overwrite_runtime = FALSE,
  reinstall_gdalraster = FALSE,
  quiet = FALSE
) -> invisible(list)
```

## default safety contract

- runtime install defaults to `overwrite = FALSE`
- source install defaults to package-managed isolated library:
  - `tools::R_user_dir("gdalraster.windows", "data")/rlib`
- no default mutation of `~/.Renviron` or `~/.Rprofile`
- no default overwrite of existing `gdalraster` in user/global `.libPaths()`

## required implementation patterns

- all temporary build/session state must be scoped with `withr`:
  - `withr::with_makevars()`
  - `withr::with_envvar()`
  - `withr::with_libpaths()`
- all user-facing errors/messages use `cli`:
  - `cli::cli_abort()`
  - `cli::cli_alert_info()`
  - `cli::cli_alert_success()`
  - `cli::cli_alert_warning()`
  - `cli::cli_alert_danger()`
- argument and call context from `rlang`:
  - `arg = rlang::caller_arg(x)`
  - `call = rlang::caller_env()`
- dynamic GDAL top-level DLL detection must support `libgdal-*.dll` (no hardcoded `-39`)

## workflow contracts

### 1) runtime install + activate

1. resolve release asset from GitHub
2. download and unzip to temp dir
3. detect GDAL root containing `bin/libgdal-*.dll`
4. install into `gdal_home`
5. activate runtime:
   - prepend `PATH` with `gdal_home/bin`
   - set `GDAL_DATA`, `PROJ_DATA`, `PROJ_LIB` when present
   - preload top-level GDAL DLL if requested

### 2) source build of gdalraster in isolated lib

1. create/use target `lib`
2. apply temporary Makevars + env scoped with `withr`
3. install `gdalraster` source from CRAN or GitHub ref
4. restore previous session/build state automatically
5. return install metadata

### 3) verification

1. optionally activate runtime
2. load `gdalraster` from target `lib`
3. report GDAL version and algorithm registry count
4. fail when `require_algorithms = TRUE` and count is zero

## trade-offs

### explicit activation vs auto-activation

- explicit activation (preferred primary path):
  - pros: deterministic, testable, less hidden state
  - cons: one additional user call
- auto-activation in `.onLoad`:
  - pros: convenience
  - cons: hidden side effects and harder debugging

### source selection default

- CRAN source default:
  - pros: stable release tarball
  - cons: slower access to upstream fixes
- GitHub source default:
  - pros: latest fixes
  - cons: potentially less stable/reproducible

### bootstrap wrapper

- keep granular functions as first-class API
- optional `bootstrap_gdalraster()` may wrap the full flow for convenience
- diagnostics should still expose per-step outcomes

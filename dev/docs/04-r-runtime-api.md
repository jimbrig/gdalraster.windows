# r runtime api

This is the companion helper layer, not the primary deliverable. Keep this doc minimal and update it as the helper surface evolves.

## exported functions

### `gdal_home()`

Returns the active GDAL runtime home path using this precedence:

1. `options(gdalraster.windows.gdal_home = "...")`
2. `GDALRASTER_WINDOWS_GDAL_HOME` environment variable
3. package-managed user data default path

### `configure_gdal_home(path, mode = c("option", "env"))`

Configures runtime home for current session via:

- R option (`mode = "option"`)
- environment variable (`mode = "env"`)

### `install_gdal_runtime(repo = "jimbrig/gdalraster.windows", tag = "latest", asset_pattern, gdal_home, overwrite = FALSE)`

- resolves release metadata through GitHub API
- downloads matching zip asset
- extracts and installs runtime tree into `gdal_home`
- validates expected GDAL DLL presence via install checks

### `activate_gdal_runtime(gdal_home = default_gdal_home(), preload = TRUE, quiet = FALSE)`

- ensures runtime paths/files exist
- prepends runtime `bin` directory to `PATH`
- sets `GDAL_DATA`, `PROJ_LIB`, and `PROJ_DATA` when available
- optionally preloads `libgdal-*.dll` discovered in runtime `bin/`

### `load_gdal_dll(gdal_home = default_gdal_home(), quiet = FALSE)`

- convenience wrapper for `activate_gdal_runtime(..., preload = TRUE)`

### `install_gdalraster(gdal_home, lib, source_tarball = NULL, repo = "firelab/gdalraster", ref = "HEAD", ...)`

- installs `gdalraster` from source on the local machine
- uses `withr::with_makevars()` + `withr::with_envvar()` so compile/link settings are scoped to the install call
- defaults to an isolated library path under this package's user data directory

### `load_gdalraster(lib = default_gdalraster_lib(), gdal_home = default_gdal_home(), quiet = FALSE)`

- activates bundled runtime
- prepends isolated library path to `.libPaths()`
- attaches `gdalraster`

### `verify_gdalraster_runtime(lib.loc = NULL, activate_runtime = TRUE, gdal_home = default_gdal_home())`

- optionally activates runtime
- loads `gdalraster`
- checks `gdal_global_reg_names()` is non-empty
- returns version and registry details

## session behavior

[`R/zzz.R`](../../R/zzz.R) auto-activates runtime at package load when option `gdalraster.windows.auto_activate` is `TRUE` (default).

## minimal user flow

```r
gdalraster.windows::install_gdal_runtime()
gdalraster.windows::install_gdalraster()
gdalraster.windows::load_gdalraster()
gdalraster.windows::verify_gdalraster_runtime()
```

## implementation notes

- runtime checks discover `libgdal-*.dll` dynamically
- package intentionally aborts on non-Windows platforms

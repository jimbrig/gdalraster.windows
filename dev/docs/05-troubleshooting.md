# troubleshooting

## baseline triage flow

1. verify active runtime root:
   - `gdalraster.windows::gdal_home()`
   - check `<gdal_home>/bin/libgdal-*.dll` exists
2. activate runtime:
   - `gdalraster.windows::activate_gdal_runtime()`
3. verify behavior:
   - `gdalraster.windows::verify_gdalraster_runtime()`
4. if still failing, audit the bundle dependency tree:
   - `ntldd -R <gdal_home>/bin/libgdal-*.dll` from an MSYS2/Rtools shell

Quick checks in R:

```r
gdalraster.windows::gdal_home()
gdalraster.windows::activate_gdal_runtime()
gdalraster.windows::verify_gdalraster_runtime()
```

## symptom matrix

### `gdal_global_reg_names()` is empty

Most likely:

- wrong GDAL DLL is loaded first
- runtime activation/path setup did not apply to this session

First actions:

- run `activate_gdal_runtime()` in a fresh R session
- check PATH ordering for conflicting GDAL roots

### `LoadLibrary` failure on package load

Most likely:

- missing transitive DLLs in runtime `bin`
- profile/path setup points to mixed toolchain DLLs

First actions:

- run bundle audit and inspect unresolved entries
- test with explicit PATH injection in `Rscript` to isolate profile effects

Example:

```powershell
Rscript -e "gdalraster.windows::activate_gdal_runtime(); library(gdalraster); print(length(gdalraster::gdal_global_reg_names()))"
```

### embedded-python algorithm fails with `ModuleNotFoundError: No module named 'osgeo_utils'`

Applies to GDAL algorithms implemented in Python, e.g. `driver gpkg validate`.

Most likely:

- runtime bundle predates `python/osgeo_utils` support
- `PYTHONPATH` was not set in this session (activation did not run)

First actions:

- check `dir.exists(file.path(gdalraster.windows::gdal_home(), "python", "osgeo_utils"))`;
  if missing, reinstall: `install_gdal_runtime(overwrite = TRUE)`
- run `activate_gdal_runtime()` and confirm
  `Sys.getenv("PYTHONPATH")` contains `<gdal_home>/python`
- confirm a `python.exe` is discoverable on `PATH` (GDAL needs one to embed an
  interpreter; the GDAL debug stream shows which python/libpython it loads)

Note: `validate_gpkg` treats the compiled `osgeo` bindings as optional; without
them it still runs all checks except tiled gridded coverage content checks.

### install/test-load fails but manual session works

Most likely:

- install-time subprocess environment differs from final runtime session

First actions:

- use controlled install flow and verify after explicit activation
- avoid assuming install-time subprocesses inherit final runtime PATH

### CI green, end-user runtime broken

Most likely:

- smoke test not reproducing real runtime activation path
- release asset naming/pattern drift

First actions:

- align smoke test with `activate_gdal_runtime()` + registry check
- validate release asset names against `install_gdal_runtime()` `asset_pattern`

## maintenance checks after GDAL upgrade

- avoid fixed soname assumptions; use `libgdal-*.dll` discovery
- ensure CI verification and docs use same naming assumptions
- re-run runtime verification from a fresh Windows session

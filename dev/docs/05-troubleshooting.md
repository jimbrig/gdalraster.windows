# troubleshooting

## baseline triage flow

1. verify active runtime root:
   - `gdalraster.windows::gdal_home()`
   - check `<gdal_home>/bin/libgdal-39.dll` exists
2. activate runtime:
   - `gdalraster.windows::activate_gdal_runtime()`
3. verify behavior:
   - `gdalraster.windows::verify_gdalraster_runtime()`
4. if still failing, audit bundle:
   - [`tools/audit_gdal_bundle.ps1`](../../tools/audit_gdal_bundle.ps1)

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

- update soname references (`libgdal-39.dll`) in `R/` and scripts
- ensure CI verification and docs use same naming assumptions
- re-run runtime verification from a fresh Windows session

# ci and release

This document describes the current pipeline shape. The GDAL build/bundle stage
is primary; `gdalraster` source-build verification is a secondary companion
stage.

For flag-level build rationale and ABI/toolchain notes, see
[`06-toolchain-and-abi.md`](06-toolchain-and-abi.md).

## workflow entrypoint

Primary pipeline: [`.github/workflows/build.yml`](../../.github/workflows/build.yml)

Triggers:

- `workflow_dispatch` with configurable GDAL and R versions
- tag push matching `gdal-v*` for release publication

## job structure

### job 1: `build-gdal`

- configures MSYS2 `UCRT64`
- restores/saves GDAL build cache keyed to version and script hash
- runs [`tools/build_gdal.sh`](../../tools/build_gdal.sh) (also stages
  pure-python `osgeo_utils` from the GDAL source tree into the install prefix)
- runs [`tools/collect_dlls.sh`](../../tools/collect_dlls.sh) (carries
  `python/` into the bundle alongside `bin`, `include`, `lib`, `share`)
- verifies runtime bundle integrity
- uploads intermediate artifact for downstream job
- on tag builds, publishes runtime bundle zip to GitHub release

note: release publication happens inside job 1, so a job 2 failure can leave a
published release asset alongside a red workflow run.

### job 2: `verify-gdalraster-build`

- installs R and Rtools45
- downloads runtime bundle artifact from job 1
- writes `Makevars.win` to point source compilation at bundled GDAL headers/libs
- builds `gdalraster` Windows binary from source
- runs smoke test for GDAL load and algorithm registry presence
- runs embedded-python smoke test: creates a GeoPackage, sets `PYTHONPATH` to
  the bundle `python/` dir, runs `driver gpkg validate`, asserts success
- uploads verification artifact

## release artifacts to expect

- runtime bundle zip (GDAL files and DLL dependencies)
- workflow artifact containing `gdalraster` Windows binary built against that runtime

## local rehearsal tools

- `ntldd -R <gdal_home>/bin/libgdal-*.dll` (from an MSYS2/Rtools shell):
  inspect the transitive DLL dependency tree of a local bundle
- a dedicated bundle audit script (`tools/audit_gdal_bundle.ps1`) is planned
  but not yet present in the repository

## common CI maintenance tasks

- when build scripts change, confirm cache key includes those script paths
- avoid hardcoded soname references; use `libgdal-*.dll` discovery
- keep release asset names and README install examples in sync

## upstream-sensitive checks

- verify workflow assumptions against current GDAL algorithm registry behavior after any GDAL baseline bump
- verify muparser-related package availability in build environment before configuring GDAL
- keep smoke tests aligned with real runtime activation path, not only compile/link success

## known drift risks

- docs implying package-binary publication from this workflow (current workflow
  publishes runtime bundle release asset, not `gdalraster.windows` release binary)
- package architecture text implying `inst/gdal` vendoring while current code
  expects install-and-activate model
- CI success masking runtime startup issues if tests do not reproduce end-user
  PATH/data-var conditions

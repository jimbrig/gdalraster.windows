# ci and release

This document describes the current pipeline shape. The GDAL build/bundle stage is primary; the R packaging stage is a secondary companion stage and may change as distribution strategy evolves.

## workflow entrypoint

Primary pipeline: [`.github/workflows/build.yml`](../../.github/workflows/build.yml)

Triggers:

- `workflow_dispatch` with configurable GDAL and R versions
- tag push matching `gdal-v*` for release publication

## job structure

### job 1: `build-gdal`

- configures MSYS2 `UCRT64`
- restores/saves GDAL build cache keyed to version and script hash
- runs [`tools/build_gdal.sh`](../../tools/build_gdal.sh)
- runs [`tools/collect_dlls.sh`](../../tools/collect_dlls.sh)
- verifies runtime bundle integrity
- uploads intermediate artifact for downstream job
- on tag builds, publishes runtime bundle zip to GitHub release

### job 2: `build-r-package`

- installs R and Rtools45
- downloads runtime bundle artifact from job 1
- writes `Makevars.win` to point package compilation at bundled GDAL headers/libs
- builds `gdalraster` binary and wrapper package binary
- runs smoke test for GDAL load and algorithm registry presence
- uploads package zips
- on tag builds, publishes package zips to GitHub release

## release artifacts to expect

- runtime bundle zip (GDAL files and DLL dependencies)
- `gdalraster` Windows binary built against that runtime
- `gdalraster.windows` Windows binary

## local rehearsal tools

- [`tools/audit_gdal_bundle.ps1`](../../tools/audit_gdal_bundle.ps1): inspect and repair local bundle dependency state
- outputs `.audit` reports under selected bundle path

## common CI maintenance tasks

- when build scripts change, confirm cache key includes those script paths
- when GDAL soname changes, update checks that reference `libgdal-39.dll`
- keep release asset names and README install examples in sync

## upstream-sensitive checks

- verify workflow assumptions against current GDAL algorithm registry behavior after any GDAL baseline bump
- verify muparser-related package availability in build environment before configuring GDAL
- keep smoke tests aligned with real runtime activation path, not only compile/link success

## known drift risks

- release copy may reference historical package naming (`gdal.win`) instead of `gdalraster.windows`
- package architecture text may imply `inst/gdal` bundling while current code expects install-and-activate model
- CI success can mask runtime startup issues if tests do not reproduce end-user PATH/data-var conditions

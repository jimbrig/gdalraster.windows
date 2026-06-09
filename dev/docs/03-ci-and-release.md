# ci and release

This document describes the current pipeline shape. CI has exactly one
responsibility: build, verify, and publish the GDAL runtime bundle.

Building `gdalraster` against the bundle is package functionality
(`install_gdalraster()` with `withr::with_makevars()` scoping) exercised on
user machines and by package tests — it is intentionally not a CI stage.

For flag-level build rationale and ABI/toolchain notes, see
[`06-toolchain-and-abi.md`](06-toolchain-and-abi.md).

## workflow entrypoint

Primary pipeline: [`.github/workflows/build.yml`](../../.github/workflows/build.yml)

Triggers:

- `workflow_dispatch` with configurable GDAL version, force-rebuild flag, and
  `publish_release` toggle (defaults to `true`)
- tag push matching `gdal-v*` for release publication

## job structure

Single job: `build-gdal`

- configures MSYS2 `UCRT64`
- restores/saves GDAL build cache keyed to version and script hash; a cache
  hit skips the compile entirely (re-dispatch republishes in minutes)
- runs [`tools/build_gdal.sh`](../../tools/build_gdal.sh) (also stages
  pure-python `osgeo_utils` from the GDAL source tree into the install prefix)
- runs [`tools/collect_dlls.sh`](../../tools/collect_dlls.sh) (carries
  `python/` into the bundle alongside `bin`, `include`, `lib`, `share`)
- verifies bundle contract: `bin/libgdal-*.dll`, `share/gdal`, `share/proj`,
  `python/osgeo_utils/samples/validate_gpkg.py`
- always uploads the bundle as a 30-day workflow artifact and creates the
  distributable zip, so no build is wasted when publication is skipped
- publishes the zip to the GitHub release on tag pushes or when
  `publish_release=true`
- writes a build summary (cache vs fresh build, bundle composition, artifact
  and release destinations) to the run summary page

## release artifacts to expect

- runtime bundle zip (GDAL files, DLL dependencies, data dirs, python utils)
- 30-day workflow artifact with identical bundle contents on every run

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

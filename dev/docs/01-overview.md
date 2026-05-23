# overview

## mission

`gdalraster.windows` exists to build and distribute a portable GDAL runtime for Windows with reliable algorithm support.

The key requirement is a reproducible GDAL runtime build and bundle process for Windows. `GDAL_USE_MUPARSER=ON` is enabled for expression support, but it is tracked separately from the historical static-registration issue that affected algorithm discovery.

## core problem

In default setups, Windows users can end up with a GDAL runtime where:

- `gdalraster` installs, but
- `gdalraster::gdal_global_reg_names()` returns `character(0)`.

This project closes that gap with a custom GDAL build and distribution pipeline, plus lightweight runtime activation helpers.

## repository responsibilities

1. build GDAL from source in UCRT64 with flags needed for algorithm registry support
2. collect and verify transitive runtime DLL dependencies for portable use
3. publish versioned runtime artifacts from CI
4. provide a small companion R helper layer for runtime activation and verification

## canonical architecture choices

- runtime model: **download and activate** (not `inst/gdal` vendoring in current root package)
- package name: **`gdalraster.windows`** (treat `gdal.win` as historical prototype naming)
- build target: MSYS2 `UCRT64` with `GDAL_USE_MUPARSER=ON`
- dependency closure: collect transitive runtime DLLs and fail when unresolved non-Windows deps remain

## high-level flow

1. CI compiles GDAL and assembles `gdal-bundle/` (`bin`, `include`, `lib`, `share`).
2. CI uses that bundle to build Windows binaries for `gdalraster` and `gdalraster.windows`.
3. End users install runtime and package artifacts, then call activation/verification helpers.

## upstream status snapshot

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826): documented algorithm-registry failure mode
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592): upstream fix for static top-level algorithm registration, backported to GDAL 3.12.2
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858) and [mxe/mxe#3277](https://github.com/mxe/mxe/pull/3277): muparser enablement and update path in Rtools/MXE ecosystem
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982): practical Windows workflow proving compile-time and runtime path requirements

## source-of-truth boundaries

- production implementation: root [`R/`](../../R), [`tools/`](../../tools), [`.github/workflows/`](../../.github/workflows)
- curated maintainer docs: [`dev/docs/`](.)
- historical context and prototypes: [`dev/temp/`](../temp)

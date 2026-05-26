# runtime model

This note describes how the current implementation works.

It is not a policy document. If behavior changes in code, update this file to
match the implementation.

## scope

`gdalraster.windows` currently provides:

1. a Windows GDAL runtime bundle build/release path
2. R helpers to install and activate that runtime
3. a source-build flow for `gdalraster` against that runtime

## compile-time path

`install_gdalraster()` sets scoped Makevars so source builds resolve:

- headers from `<gdal_home>/include`
- import libraries from `<gdal_home>/lib`

The intent is to link against the installed bundle, not a default toolchain
GDAL.

## runtime path

`activate_gdal_runtime()` currently:

- prepends `<gdal_home>/bin` to `PATH`
- sets `GDAL_DATA`, `PROJ_LIB`, and `PROJ_DATA` when available
- optionally preloads `libgdal-*.dll` with `dyn.load()`

This is the mechanism used today to make runtime loading reliable in typical
Windows sessions.

## runtime bundle contents

Expected runtime bundle structure:

- `bin/libgdal-*.dll`
- bundled non-Windows transitive dependency DLLs
- `share/gdal`
- `share/proj`

`tools/collect_dlls.sh` performs dependency collection and closure checks in CI.

## default install behavior

Default package behavior is non-destructive:

- runtime installs under `tools::R_user_dir()`
- `gdalraster` source install targets an isolated library path
- persistent startup changes are optional (`add_gdal_rprofile_hook()`)

## practical verification

A quick implementation check in a fresh session:

1. `gdalraster.windows::activate_gdal_runtime()`
2. `library(gdalraster)`
3. `length(gdalraster::gdal_global_reg_names()) > 0`

## references

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826)
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858)
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)
- [Rtools45 news](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html)

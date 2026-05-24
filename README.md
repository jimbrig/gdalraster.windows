# gdalraster.windows

[![Build GDAL + verify gdalraster (Windows)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml)
[![Generate Changelog](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml)

> [!NOTE]
> Self-contained [GDAL](https://gdal.org/) runtime tooling for Windows.

This project builds and distributes a portable Windows GDAL runtime bundle, with
R helpers to install that runtime locally and build `gdalraster` from source
against it.

Latest GDAL runtime release:
[gdal-v3.13.0](https://github.com/jimbrig/gdalraster.windows/releases/tag/gdal-v3.13.0)

## Installation

```r
pak::pak("jimbrig/gdalraster.windows")
```

## Usage

```r
# baseline with default gdalraster on windows can be empty
library(gdalraster)
gdalraster::gdal_global_reg_names()
#> character(0)   # typical before custom runtime + rebuild

# 1) download and install the GDAL runtime bundle (defaults to latest release)
gdalraster.windows::install_gdal_runtime()

# 2) build gdalraster from source against that runtime
# default installs to an isolated package-managed library path
gdalraster.windows::install_gdalraster()

# optional: build to your active library instead
# gdalraster.windows::install_gdalraster(lib = .libPaths()[1])

# 3) streamlined bootstrap:
# library(gdalraster.windows) auto-bootstraps runtime + custom lib path
library(gdalraster.windows)

# explicit equivalents (still available):
# gdalraster.windows::load_gdal_dll()
# gdalraster.windows::load_gdalraster()

# 4) verify algorithm api availability (returns TRUE/FALSE + sitrep)
ok <- gdalraster.windows::verify_gdalraster_runtime()
ok

# direct check
gdalraster::gdal_global_reg_names()
#> [1] "raster info" "raster pipeline" ...
```

## Optional startup hook (.Rprofile)

```r
# writes a managed hook block that loads the GDAL DLL and prepends
# the custom gdalraster library path at session startup
gdalraster.windows::add_gdal_rprofile_hook()
```

For package API details, see [dev/docs/04-r-runtime-api.md](dev/docs/04-r-runtime-api.md).

## Background context

Key upstream background:

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826)
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858)
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)
- [Rtools45 news](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html)
- [mxe/mxe#3277](https://github.com/mxe/mxe/pull/3277)

## Documentation

For maintainers and contributors:

- [dev/docs/README.md](dev/docs/README.md)

 
# gdalraster.windows

[![Build GDAL + verify gdalraster (Windows)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml)
[![Generate Changelog](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml)

> [!NOTE]
> Self-contained [GDAL](https://gdal.org/) runtime tooling for Windows.

This project builds and distributes a portable Windows GDAL runtime bundle, with
R helpers to install that runtime locally and build `gdalraster` from source
against it.

## Installation

```r
install.packages("pak")
pak::pak("jimbrig/gdalraster.windows")
```

## Default workflow (R)

```r
# 1) install runtime from release asset (or optional local fallback zip)
gdalraster.windows::install_gdal_runtime(
  repo = "jimbrig/gdalraster.windows",
  tag = "gdal-v3.13.0"
)

# 2) build gdalraster from source against that runtime
gdalraster.windows::install_gdalraster()

# 3) activate runtime and load gdalraster
gdalraster.windows::load_gdalraster()

# 4) verify algorithm api availability
out <- gdalraster.windows::verify_gdalraster_runtime()
out$algorithm_count
```

## Quick start (runtime bundle only)

1. Open [Releases](https://github.com/jimbrig/gdalraster.windows/releases).
2. Download the latest Windows GDAL runtime bundle asset.
3. Use that bundle in your downstream workflow (R or non-R) where a portable GDAL runtime is needed.

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

 
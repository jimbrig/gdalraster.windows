# gdalraster.windows

[![Build GDAL + gdalraster (Windows)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml)
[![Generate Changelog](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml)

> [!NOTE]
> Self-contained [GDAL](https://gdal.org/) runtime tooling for Windows.

This project builds and distributes a portable Windows GDAL runtime bundle, with a focus on reliable algorithm support and practical runtime portability.

## Quick start

1. Open [Releases](https://github.com/jimbrig/gdalraster.windows/releases).
2. Download the latest Windows GDAL runtime bundle asset.
3. Use that bundle in your downstream workflow (R or non-R) where a portable GDAL runtime is needed.

If you are using the companion R helper package, see [dev/docs/04-r-runtime-api.md](dev/docs/04-r-runtime-api.md).

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

 
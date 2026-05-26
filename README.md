# gdalraster.windows

<!-- badges: start -->

[![R CMD CHECK](https://github.com/jimbrig/gdalraster.windows/actions/workflows/check.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/R-CMD-check.yaml)
[![Build GDAL](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml)
[![Changelog](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml)

 <!-- badges: end -->

> [!NOTE]
> Self-contained [GDAL](https://gdal.org/) runtime tooling for Windows.

`gdalraster.windows` is an R package with companion CI scripts that build and
publish a Windows GDAL runtime bundle.

The package helps you:

- install that runtime locally
- build `gdalraster` from source against it
- load and verify `gdalraster` in a Windows session

By default, installs are isolated under package-managed user directories.

Latest GDAL runtime release:
[gdal-v3.13.0](https://github.com/jimbrig/gdalraster.windows/releases/tag/gdal-v3.13.0)

## Installation

```r
pak::pak("jimbrig/gdalraster.windows")
```

## Quick Start

```r
# 1) install runtime bundle (defaults to latest release asset)
gdalraster.windows::install_gdal_runtime()

# 2) build gdalraster from source against that runtime
gdalraster.windows::install_gdalraster()

# 3) load and verify
library(gdalraster.windows)
gdalraster::gdal_global_reg_names()
```

## Common Flows

If runtime and custom `gdalraster` install are already present:

```r
library(gdalraster.windows)
library(gdalraster)
gdalraster::gdal_global_reg_names()
```

Explicit load flow is also supported:

```r
gdalraster.windows::load_gdal_dll()
gdalraster.windows::load_gdalraster()
gdalraster::gdal_global_reg_names()
```

Runtime verification helper:

```r
gdalraster.windows::verify_gdalraster_runtime()
```

## What This Repository Contains

- An R helper package (`gdalraster.windows`)
- A Windows CI build pipeline for GDAL (`.github/workflows/build.yml`)
- Build and bundle scripts:
  - `tools/build_gdal.sh`
  - `tools/collect_dlls.sh`

The package and build scripts are designed to work together.

## Optional startup hook (`.Rprofile`)

```r
# writes a managed hook block that loads the GDAL DLL and prepends
# the custom gdalraster library path at session startup
gdalraster.windows::add_gdal_rprofile_hook()
```

## Why This Exists

This repository started from practical Windows failures where
`gdalraster::gdal_global_reg_names()` could be empty under some toolchain
states. It now provides a maintained runtime path that is isolated by default.

## Technical background

Upstream context:

- [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826)
- [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858)
- [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982)
- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592)
- [Rtools45 news](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html)

Maintainer documentation:

- [`dev/docs/`](dev/docs)
- [`dev/docs/README.md`](dev/docs/README.md)

Package guide:

- [`vignettes/runtime-guide.Rmd`](vignettes/runtime-guide.Rmd)

## Testing

Run fast tests:

```r
testthat::test_dir("tests/testthat")
```

Run clean-room isolation checks:

```r
testthat::test_file("tests/testthat/test-e2e-clean-room.R")
```

Run full end-to-end clean-room flow (opt-in):

```powershell
$env:GDALRASTER_WINDOWS_RUN_E2E="true"
Rscript -e "testthat::test_file('tests/testthat/test-e2e-clean-room.R')"
```

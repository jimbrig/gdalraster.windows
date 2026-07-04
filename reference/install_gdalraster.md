# Install gdalraster from source against bundled GDAL

Downloads or uses a local gdalraster source tarball and installs it from
source into a dedicated library path (default) so existing user
libraries are not overwritten. To install into your regular user library
instead (so plain
[`library(gdalraster)`](https://firelab.github.io/gdalraster/) resolves
the source build without this package's load helpers), pass it
explicitly, e.g. `install_gdalraster(lib = .libPaths()[1])`.

## Usage

``` r
install_gdalraster(
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib(),
  source_tarball = NULL,
  repo = .gdalraster_repo,
  ref = "HEAD",
  upgrade = FALSE,
  repos = getOption("repos")
)
```

## Arguments

- gdal_home:

  GDAL home directory used for compile/link flags.

- lib:

  Destination library path for installing gdalraster. Defaults to an
  isolated package-managed library; pass `.libPaths()[1]` to install
  into your default user library.

- source_tarball:

  Optional local path to `gdalraster_*.tar.gz`.

- repo:

  Source GitHub repo slug for gdalraster. Defaults to
  `"firelab/gdalraster"`.

- ref:

  Git ref (branch, tag, commit) used when downloading from GitHub.

- upgrade:

  When `TRUE`, missing R package dependencies of gdalraster are
  installed from `repos` before the source build. Has no effect on the
  compile/link flags used to build gdalraster itself.

- repos:

  CRAN-like repositories used to satisfy R package dependencies when
  `upgrade = TRUE`. Ignored when `upgrade = FALSE`.

## Value

Invisibly returns installed library path.

## Prerequisites

This is a source compilation, so
[Rtools](https://cran.r-project.org/bin/windows/Rtools/) matching your R
version must be installed (the one thing the prebuilt runtime bundle
cannot eliminate). The function checks for a toolchain up front and
aborts with guidance when none is found. The GDAL runtime bundle itself
must already be installed via
[`install_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdal_runtime.md).

## Upgrading

After installing a new runtime bundle version
(`install_gdal_runtime(overwrite = TRUE)`), rerun this function — the
previous gdalraster build is bound to the previous bundle's GDAL and
must be recompiled against the new one.

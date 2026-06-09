# Install gdalraster from source against bundled GDAL

Downloads or uses a local gdalraster source tarball and installs it from
source into a dedicated library path (default) so existing user
libraries are not overwritten.

## Usage

``` r
install_gdalraster(
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib(),
  source_tarball = NULL,
  repo = "firelab/gdalraster",
  ref = "HEAD",
  upgrade = FALSE,
  repos = getOption("repos")
)
```

## Arguments

- gdal_home:

  GDAL home directory used for compile/link flags.

- lib:

  Destination library path for installing gdalraster.

- source_tarball:

  Optional local path to `gdalraster_*.tar.gz`.

- repo:

  Source GitHub repo slug for gdalraster.

- ref:

  Git ref (branch, tag, commit) used when downloading from GitHub.

- upgrade:

  Whether to allow dependency upgrades during install.

- repos:

  CRAN-like repositories passed to
  [`utils::install.packages()`](https://rdrr.io/r/utils/install.packages.html).

## Value

Invisibly returns installed library path.

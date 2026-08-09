# Build a self-contained gdalraster package

Compiles `gdalraster` against the managed GDAL SDK, vendors the bundle's
DLL dependency closure, GDAL/PROJ data, and pure-Python utilities into
the installed package, then records build provenance.

## Usage

``` r
gdal_build_gdalraster(
  gdal_home = default_gdal_home(),
  lib = NULL,
  user_lib = FALSE,
  source_tarball = NULL,
  repo = .gdalraster_repo,
  ref = "HEAD",
  upgrade = FALSE,
  repos = getOption("repos"),
  force = FALSE,
  enable_python = TRUE
)
```

## Arguments

- gdal_home:

  Installed GDAL build runtime.

- lib:

  Destination library. The default is an isolated package-managed
  library.

- user_lib:

  Install into `.libPaths()[1]`. This is destructive when an existing
  `gdalraster` is installed there and requires `force = TRUE` in
  non-interactive sessions.

- source_tarball:

  Optional local `gdalraster` source tarball.

- repo:

  Upstream source repository.

- ref:

  Git reference used for the source archive.

- upgrade:

  Install missing R dependencies before compiling.

- repos:

  CRAN-like repositories used when `upgrade = TRUE`.

- force:

  Replace an existing `gdalraster` package.

- enable_python:

  Provision the managed embedded-Python `.pth` file after installation
  when possible.

## Value

Invisibly, the destination library.

# Build a self-contained gdalraster package

Compiles `gdalraster` against the managed GDAL SDK, vendors the bundle's
DLL dependency closure, GDAL/PROJ data, and pure-Python utilities into
the installed package, then records build provenance.

## Usage

``` r
gdal_build_gdalraster(
  gdal_home = default_gdal_home(),
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
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

  Destination library. Defaults to `.libPaths()[1]`.

- isolated:

  Install into the package-managed isolated library instead of
  `.libPaths()[1]`. Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

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

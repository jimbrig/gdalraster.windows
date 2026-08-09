# Getting Started

## What the package installs

`gdalraster.windows` downloads a verified GDAL build runtime, compiles
[`gdalraster`](https://firelab.github.io/gdalraster/) against it, and
vendors the complete native dependency closure into the installed
`gdalraster` package. The result carries:

- GDAL and dependency DLLs under `libs/x64`;
- matching GDAL and PROJ data under `gdal/` and `proj/`;
- pure-Python `osgeo_utils` under `python/`; and
- a provenance manifest recording the bundle used for the build.

No `.Rprofile` hook, `PATH` edit, DLL preload, or GDAL/PROJ environment
variable is needed in later sessions.

## Prerequisites

- Windows and R.
- The matching [Rtools](https://cran.r-project.org/bin/windows/Rtools/)
  release. Compilation is the only step the prebuilt GDAL bundle cannot
  remove.

## One-time setup

Install the package, then build into your regular user library when you
want plain
[`library(gdalraster)`](https://firelab.github.io/gdalraster/) in every
later session:

``` r

pak::pak("jimbrig/gdalraster.windows")
gdalraster.windows::gdal_setup(user_lib = TRUE)
```

[`gdal_setup()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_setup.md)
prints one plan, installs or skips the runtime idempotently, builds and
vendors `gdalraster`, provisions embedded Python when a system CPython
is available, and verifies the result in fresh processes.

The package’s non-destructive default is an isolated managed library:

``` r

result <- gdalraster.windows::gdal_setup()
result$lib
```

Use `user_lib = TRUE` explicitly to replace a package in
`.libPaths()[1]`. Interactive sessions ask before replacement;
non-interactive replacement requires explicit arguments.

## Everyday use

After a user-library setup, `gdalraster.windows` does not need to be
attached:

``` r

library(gdalraster)
gdalraster::gdal_global_reg_names()
```

For an isolated install, provide its library location:

``` r

library(
  gdalraster,
  lib.loc = file.path(
    tools::R_user_dir("gdalraster.windows", "data"),
    "library"
  )
)
```

## Status and verification

``` r

gdalraster.windows::gdal_sitrep(user_lib = TRUE)
gdalraster.windows::gdal_verify(user_lib = TRUE)
```

[`gdal_verify()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_verify.md)
uses fresh `Rscript --vanilla` processes. It checks the Algorithm API,
GEOS and CRS support, Arrow, Parquet, HDF5, and netCDF driver
registration, a first Parquet open, and the GeoPackage Python validator
when Python provisioning is ready.

## Updating

``` r

gdalraster.windows::gdal_update(user_lib = TRUE)
```

The runtime and built package manifests let this operation distinguish a
current build from one that must be rebuilt.

## Offline setup

Download a bundle release asset on a connected machine, transfer it,
then use:

``` r

gdalraster.windows::gdal_setup(
  user_lib = TRUE,
  local_zip = "C:/Downloads/gdal-bundle-v3.13.2-windows-x64.zip"
)
```

See the [Runtime
Guide](https://docs.jimbrig.com/gdalraster.windows/articles/runtime-guide.md)
for layout and provenance details,
[Architecture](https://docs.jimbrig.com/gdalraster.windows/articles/architecture.md)
for the loading model, and
[Troubleshooting](https://docs.jimbrig.com/gdalraster.windows/articles/troubleshooting.md)
for diagnosis.

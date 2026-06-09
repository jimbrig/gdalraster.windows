# Build an .Rprofile hook snippet for bundled GDAL

Returns R code that loads the bundled GDAL DLL before attaching
`gdalraster`, and prepends the custom `lib` path so
[`library(gdalraster)`](https://firelab.github.io/gdalraster/) resolves
to the source build installed by
[`install_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdalraster.md).

## Usage

``` r
gdal_rprofile_snippet(
  gdal_home = default_gdal_home(),
  lib = default_gdalraster_lib()
)
```

## Arguments

- gdal_home:

  GDAL home directory.

- lib:

  Library path containing the custom gdalraster install.

## Value

A single string containing R code.

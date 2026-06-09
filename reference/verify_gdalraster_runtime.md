# Verify gdalraster algorithm API availability

Attempts to load `gdalraster` and checks the global algorithm registry.

## Usage

``` r
verify_gdalraster_runtime(
  lib.loc = NULL,
  activate_runtime = TRUE,
  gdal_home = default_gdal_home(),
  quiet = FALSE
)
```

## Arguments

- lib.loc:

  Optional library location used for loading `gdalraster`.

- activate_runtime:

  Whether to run
  [`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
  first.

- gdal_home:

  GDAL home used when `activate_runtime = TRUE`.

- quiet:

  If `TRUE`, suppress sitrep CLI output.

## Value

`TRUE` when algorithm API is available, otherwise `FALSE`.

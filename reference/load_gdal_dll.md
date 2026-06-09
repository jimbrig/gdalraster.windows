# Load GDAL DLL from runtime bundle

Convenience wrapper over
[`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
that ensures the GDAL runtime is activated and the main GDAL DLL is
preloaded in the current session.

## Usage

``` r
load_gdal_dll(gdal_home = default_gdal_home(), quiet = FALSE)
```

## Arguments

- gdal_home:

  GDAL home directory.

- quiet:

  Suppress informational CLI output.

## Value

Invisibly returns activation metadata.

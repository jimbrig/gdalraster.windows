# Load gdalraster using bundled GDAL runtime

Activates bundled GDAL runtime, prepends `lib` to
[`.libPaths()`](https://rdrr.io/r/base/libPaths.html), and attaches
gdalraster for use in the current R session.

## Usage

``` r
load_gdalraster(
  lib = default_gdalraster_lib(),
  gdal_home = default_gdal_home(),
  quiet = FALSE
)
```

## Arguments

- lib:

  Library path containing the gdalraster source install.

- gdal_home:

  GDAL home directory.

- quiet:

  Suppress informational CLI output.

## Value

Invisibly returns TRUE if gdalraster was attached.

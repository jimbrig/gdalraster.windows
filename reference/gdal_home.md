# Resolve active GDAL home path

Returns the currently configured GDAL runtime home used by this package.

## Usage

``` r
gdal_home()
```

## Value

A single string path.

## Details

Resolution order:

1.  `options(gdalraster.windows.gdal_home = "...")`

2.  `GDALRASTER_WINDOWS_GDAL_HOME` environment variable

3.  package-managed user data directory
    ([`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html))

# Resolve the managed GDAL runtime directory

Resolution order is the `gdalraster.windows.gdal_home` option, the
`GDALRASTER_WINDOWS_GDAL_HOME` environment variable, then the
package-managed user data directory.

## Usage

``` r
gdal_home()
```

## Value

A single path.

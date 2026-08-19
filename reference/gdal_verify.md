# Verify the self-contained gdalraster installation

Runs verification in fresh `Rscript --vanilla` processes. Checks the
GDAL Algorithm API, GEOS and CRS support, Arrow/Parquet/HDF5/netCDF
driver registration, a first Parquet dataset open, and the GeoPackage
Python validator when embedded Python has been provisioned.

## Usage

``` r
gdal_verify(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  python = TRUE,
  quiet = FALSE
)
```

## Arguments

- lib:

  Library containing the managed `gdalraster` package. Defaults to
  `.libPaths()[1]`.

- isolated:

  Verify the package-managed isolated library instead of
  `.libPaths()[1]`. Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

- python:

  Run the embedded-Python validation when its managed `.pth` file is
  ready.

- quiet:

  Suppress verification output.

## Value

`TRUE` on success and `FALSE` on failure.

# Verify the self-contained gdalraster installation

Runs verification in fresh `Rscript --vanilla` processes. Checks the
GDAL Algorithm API, GEOS and CRS support, Arrow/Parquet/HDF5/netCDF
driver registration, a first Parquet dataset open, and the GeoPackage
Python validator when embedded Python has been provisioned.

## Usage

``` r
gdal_verify(lib = NULL, user_lib = FALSE, python = TRUE, quiet = FALSE)
```

## Arguments

- lib:

  Library containing the managed `gdalraster` package.

- user_lib:

  Use `.libPaths()[1]`.

- python:

  Run the embedded-Python validation when its managed `.pth` file is
  ready.

- quiet:

  Suppress verification output.

## Value

`TRUE` on success and `FALSE` on failure.

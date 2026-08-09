# Uninstall managed GDAL resources

Uninstall managed GDAL resources

## Usage

``` r
gdal_uninstall(
  lib = NULL,
  user_lib = FALSE,
  runtime = TRUE,
  package = TRUE,
  python = TRUE,
  force = FALSE
)
```

## Arguments

- lib:

  Library containing the managed `gdalraster` package.

- user_lib:

  Use `.libPaths()[1]`.

- runtime:

  Remove the GDAL build runtime.

- package:

  Remove the managed `gdalraster` package.

- python:

  Remove managed embedded-Python `.pth` files.

- force:

  Confirm removal in non-interactive sessions.

## Value

Invisibly, the removed paths.

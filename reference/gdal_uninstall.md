# Uninstall managed GDAL resources

Uninstall managed GDAL resources

## Usage

``` r
gdal_uninstall(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  runtime = TRUE,
  package = TRUE,
  python = TRUE,
  force = FALSE
)
```

## Arguments

- lib:

  Library containing the managed `gdalraster` package. Defaults to
  `.libPaths()[1]`.

- isolated:

  Remove the package-managed isolated library instead of
  `.libPaths()[1]`. Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

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

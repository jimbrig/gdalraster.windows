# Update the GDAL runtime and rebuild gdalraster

Update the GDAL runtime and rebuild gdalraster

## Usage

``` r
gdal_update(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  tag = "latest",
  local_zip = NULL,
  fallback_zip = NULL,
  source_tarball = NULL,
  upgrade = FALSE,
  verify = TRUE
)
```

## Arguments

- lib:

  Destination library for `gdalraster`. Defaults to `.libPaths()[1]`.

- isolated:

  Install into the package-managed isolated library instead of
  `.libPaths()[1]`. Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

- tag:

  Runtime bundle release tag or `"latest"`.

- local_zip:

  Optional local runtime bundle.

- fallback_zip:

  Optional local fallback runtime bundle.

- source_tarball:

  Optional local `gdalraster` source tarball.

- upgrade:

  Install `gdalraster` R dependencies before compiling.

- verify:

  Run
  [`gdal_verify()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_verify.md)
  after setup.

## Value

The result of
[`gdal_setup()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_setup.md),
invisibly.

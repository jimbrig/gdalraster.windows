# Update the GDAL runtime and rebuild gdalraster

Update the GDAL runtime and rebuild gdalraster

## Usage

``` r
gdal_update(
  lib = NULL,
  user_lib = FALSE,
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

  Destination library for `gdalraster`.

- user_lib:

  Use `.libPaths()[1]` instead of the isolated managed library.

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

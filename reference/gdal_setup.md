# Set up a self-contained gdalraster installation

Installs the GDAL build runtime when needed, builds and vendors
`gdalraster`, provisions embedded Python when available, and verifies
the result in fresh processes. The default destination is
`.libPaths()[1]`.

## Usage

``` r
gdal_setup(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  update = FALSE,
  force = FALSE,
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

- update:

  Upgrade the runtime to the requested/latest bundle and rebuild.

- force:

  Reinstall and rebuild even when provenance is current.

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

Invisibly, a list describing performed actions.

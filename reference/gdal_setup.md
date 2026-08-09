# Set up a self-contained gdalraster installation

Installs the GDAL build runtime when needed, builds and vendors
`gdalraster`, provisions embedded Python when available, and verifies
the result in fresh processes.

## Usage

``` r
gdal_setup(
  lib = NULL,
  user_lib = FALSE,
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

  Destination library for `gdalraster`.

- user_lib:

  Use `.libPaths()[1]` instead of the isolated managed library.

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

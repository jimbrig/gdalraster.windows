# Install precompiled GDAL runtime

Installs the GDAL runtime into `gdal_home` from one of:

## Usage

``` r
install_gdal_runtime(
  repo = "jimbrig/gdalraster.windows",
  tag = "latest",
  asset_pattern = "gdal-(bundle|ucrt64)-.*\\.zip$",
  gdal_home = default_gdal_home(),
  overwrite = FALSE,
  local_zip = NULL,
  fallback_zip = NULL
)
```

## Arguments

- repo:

  GitHub repo slug, e.g. `"jimbrig/gdalraster.windows"`.

- tag:

  Release tag or `"latest"`.

- asset_pattern:

  Regex used to select the release asset.

- gdal_home:

  Destination GDAL home directory.

- overwrite:

  Whether to replace existing `gdal_home`.

- local_zip:

  Optional local GDAL runtime zip to install directly.

- fallback_zip:

  Optional fallback zip path used when release download fails. Defaults
  to package file `inst/extdata/gdal-ucrt64-fallback.zip`.

## Value

Invisibly returns installed GDAL home path.

## Details

- `local_zip` (highest precedence),

- GitHub release asset lookup/download,

- `fallback_zip` when release lookup/download fails.

The selected zip must contain a GDAL root with `bin/libgdal-*.dll`.

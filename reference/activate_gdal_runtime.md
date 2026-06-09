# Activate GDAL runtime for current R session

Prepends runtime paths, sets GDAL/PROJ env vars, and preloads GDAL DLL.

## Usage

``` r
activate_gdal_runtime(
  gdal_home = default_gdal_home(),
  preload = TRUE,
  quiet = FALSE
)
```

## Arguments

- gdal_home:

  GDAL home directory.

- preload:

  Whether to preload `libgdal-*.dll`.

- quiet:

  Suppress informational CLI output.

## Value

Invisibly returns a list with configured paths.

## Details

When the runtime bundle contains a `python/` directory (pure-python
`osgeo_utils` package from GDAL's `gdal-utils` distribution), it is
prepended to `PYTHONPATH` so GDAL algorithms that embed Python at
runtime (e.g. `gdal driver gpkg validate`) can import it. This is
session-scoped and does not modify machine or user environment
variables.

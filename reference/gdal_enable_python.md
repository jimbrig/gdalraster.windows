# Enable GDAL embedded-Python utilities

Writes a managed `.pth` file into the system CPython `site-packages`
directory. The file points to the pure-Python `osgeo_utils` vendored
inside the installed `gdalraster` package. This does not modify
`PYTHONPATH` and does not affect isolated virtual environments.

## Usage

``` r
gdal_enable_python(
  lib = default_gdalraster_lib(),
  python = NULL,
  site_packages = NULL,
  quiet = FALSE
)
```

## Arguments

- lib:

  Library containing the self-contained `gdalraster` package.

- python:

  Optional path to the CPython executable GDAL embeds.

- site_packages:

  Optional explicit `site-packages` directory.

- quiet:

  Suppress status messages.

## Value

Invisibly, the `.pth` path, or `NULL` when no system CPython can be
located.

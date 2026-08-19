# Enable GDAL embedded-Python utilities

Writes a managed `.pth` file into the system CPython `site-packages`
directory. The file points to the pure-Python `osgeo_utils` vendored
inside the installed `gdalraster` package. This does not modify
`PYTHONPATH` and does not affect isolated virtual environments.

## Usage

``` r
gdal_enable_python(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  python = NULL,
  site_packages = NULL,
  quiet = FALSE
)
```

## Arguments

- lib:

  Library containing the self-contained `gdalraster` package. Defaults
  to `.libPaths()[1]`.

- isolated:

  Use the package-managed isolated library instead of `.libPaths()[1]`.
  Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

- python:

  Optional path to the CPython executable GDAL embeds.

- site_packages:

  Optional explicit `site-packages` directory.

- quiet:

  Suppress status messages.

## Value

Invisibly, the `.pth` path, or `NULL` when no system CPython can be
located.

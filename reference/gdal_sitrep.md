# Report GDAL and gdalraster installation state

Reports the installed GDAL runtime, the `gdalraster` build in the active
library, staleness against the newest `gdal-v*` bundle, embedded-Python
provisioning, and session collision risks without changing the session.

## Usage

``` r
gdal_sitrep(
  lib = NULL,
  isolated = FALSE,
  user_lib = NULL,
  network = rlang::is_interactive(),
  quiet = FALSE
)
```

## Arguments

- lib:

  Library expected to contain the managed `gdalraster` build. Defaults
  to `.libPaths()[1]`.

- isolated:

  Inspect the package-managed isolated library instead of
  `.libPaths()[1]`. Ignored when `lib` is set.

- user_lib:

  Deprecated. `user_lib = TRUE` is now the default; `user_lib = FALSE`
  is equivalent to `isolated = TRUE`.

- network:

  Query GitHub for the latest GDAL runtime bundle (`gdal-v*`).

- quiet:

  Return state without printing it.

## Value

Invisibly, a named list describing installation state.

## Details

The default inspects `.libPaths()[1]`, the library used by
[`library(gdalraster)`](https://firelab.github.io/gdalraster/). Pass
`lib` for a custom library, or `isolated = TRUE` for the package-managed
isolated library.

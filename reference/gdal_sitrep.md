# Report GDAL and gdalraster installation state

Reports bundle and build provenance, staleness, embedded-Python
provisioning, and common collision risks without changing the session.

## Usage

``` r
gdal_sitrep(
  lib = NULL,
  user_lib = FALSE,
  network = rlang::is_interactive(),
  quiet = FALSE
)
```

## Arguments

- lib:

  Library expected to contain the managed `gdalraster` build.

- user_lib:

  Inspect `.libPaths()[1]` instead of the isolated library.

- network:

  Query GitHub for the latest bundle release.

- quiet:

  Return state without printing it.

## Value

Invisibly, a named list describing installation state.

# gdalraster.windows 0.1.0

## New features

- The GDAL runtime bundle now ships GDAL's pure-python `osgeo_utils` package
  (`gdal-utils`) under `<gdal_home>/python`, version-locked to the built GDAL
  tag. `activate_gdal_runtime()` prepends this directory to `PYTHONPATH`
  (session-scoped) so GDAL algorithms that embed a Python interpreter at
  runtime (e.g. `gdal driver gpkg validate`) can import it.
- `activate_gdal_runtime()` now returns `gdal_python` in its invisible result
  alongside the other configured paths.

## Documentation

- New README technical section on the embedded CPython layer and why the
  compiled `osgeo` SWIG bindings are intentionally not bundled.
- Offline / air-gapped installation documented in the README, vignette, and
  `install_gdal_runtime()` help (`local_zip` workflow).
- Troubleshooting guide gains a triage entry for
  `ModuleNotFoundError: No module named 'osgeo_utils'`.
- Maintainer docs aligned with the current bundle contract
  (`bin`, `include`, `lib`, `share`, `python`).

## Build and CI

- CI is now scoped to its single responsibility: build, verify, and publish
  the GDAL runtime bundle. The `gdalraster` source-build verification job was
  removed; building `gdalraster` against the bundle is package functionality
  (`install_gdalraster()`).
- Every CI run now produces durable output: a 30-day workflow artifact and
  the distributable zip are always created; release publication is gated on
  tag pushes or the `publish_release` dispatch input (default `true`).
- Bundle verification asserts the full runtime contract, including
  `python/osgeo_utils`.

## Package

- `gdalraster` declared in `Suggests` (resolves an R CMD check warning).

# gdalraster.windows 0.0.1

- Initial development version: GDAL runtime bundle install/activation
  helpers, `gdalraster` source-build integration, startup hooks, and the
  Windows CI build pipeline.

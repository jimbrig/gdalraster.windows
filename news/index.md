# Changelog

## gdalraster.windows 0.2.0

### Documentation

- Technical documentation promoted to published vignettes:
  [`vignette("architecture")`](https://docs.jimbrig.com/gdalraster.windows/articles/architecture.md)
  (toolchain, ABI, DLL loading, embedded python, bundle reproduction)
  and
  [`vignette("troubleshooting")`](https://docs.jimbrig.com/gdalraster.windows/articles/troubleshooting.md)
  (triage flow and symptom matrix). These are now the canonical docs;
  `dev/docs/` is explicitly non-normative maintainer notes.

### Fixes

- `tools/build_gdal.sh` discovers the produced `libgdal-*.dll` by glob
  in its final verification instead of hardcoding the SONAME, and fails
  loudly when no DLL is produced
  ([\#2](https://github.com/jimbrig/gdalraster.windows/issues/2)).
- [`install_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdal_runtime.md)
  now emits actionable guidance on download failure: the releases URL
  and the `local_zip` offline install path
  ([\#5](https://github.com/jimbrig/gdalraster.windows/issues/5)).

### Build

- GDAL runtime baseline bumped to 3.13.1 (upstream release 2026-06-05);
  default `gdal_version` in the build workflow updated accordingly.

## gdalraster.windows 0.1.0

### New features

- The GDAL runtime bundle now ships GDAL’s pure-python `osgeo_utils`
  package (`gdal-utils`) under `<gdal_home>/python`, version-locked to
  the built GDAL tag.
  [`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
  prepends this directory to `PYTHONPATH` (session-scoped) so GDAL
  algorithms that embed a Python interpreter at runtime
  (e.g. `gdal driver gpkg validate`) can import it.
- [`activate_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/activate_gdal_runtime.md)
  now returns `gdal_python` in its invisible result alongside the other
  configured paths.

### Documentation

- New README technical section on the embedded CPython layer and why the
  compiled `osgeo` SWIG bindings are intentionally not bundled.
- Offline / air-gapped installation documented in the README, vignette,
  and
  [`install_gdal_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdal_runtime.md)
  help (`local_zip` workflow).
- Troubleshooting guide gains a triage entry for
  `ModuleNotFoundError: No module named 'osgeo_utils'`.
- Maintainer docs aligned with the current bundle contract (`bin`,
  `include`, `lib`, `share`, `python`).

### Build and CI

- CI is now scoped to its single responsibility: build, verify, and
  publish the GDAL runtime bundle. The `gdalraster` source-build
  verification job was removed; building `gdalraster` against the bundle
  is package functionality
  ([`install_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/install_gdalraster.md)).
- Every CI run now produces durable output: a 30-day workflow artifact
  and the distributable zip are always created; release publication is
  gated on tag pushes or the `publish_release` dispatch input (default
  `true`).
- Bundle verification asserts the full runtime contract, including
  `python/osgeo_utils`.

### Package

- `gdalraster` declared in `Suggests` (resolves an R CMD check warning).

## gdalraster.windows 0.0.1

- Initial development version: GDAL runtime bundle install/activation
  helpers, `gdalraster` source-build integration, startup hooks, and the
  Windows CI build pipeline.

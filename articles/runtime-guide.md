# Runtime Guide

## Runtime and installed-package roles

The managed GDAL runtime is a build-time SDK. It provides headers,
import libraries, DLLs, data, and Python utilities to
[`gdal_build_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_build_gdalraster.md).
Runtime use is served entirely by files vendored inside the resulting
`gdalraster` package.

``` text
managed gdal_home/
  bin/*.dll
  include/
  lib/
  share/gdal/
  share/proj/
  python/osgeo_utils/
  MANIFEST.dcf

installed gdalraster/
  libs/x64/gdalraster.dll
  libs/x64/libgdal-*.dll
  libs/x64/<dependency DLLs>
  gdal/
  proj/
  python/osgeo_utils/
  gdalraster.windows-build.dcf
```

[`library.dynam()`](https://rdrr.io/r/base/library.dynam.html) loads
`gdalraster.dll` with the package’s `libs/x64` directory as its DLL
path. Windows resolves the dependent `libgdal` and its dependency
closure from that same directory, including when another GDAL is earlier
on `PATH`.

## Runtime location

[`gdal_home()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_home.md)
resolves:

1.  `options(gdalraster.windows.gdal_home = "...")`;
2.  `GDALRASTER_WINDOWS_GDAL_HOME`; then
3.  the package-managed user data directory.

The option and environment variable are useful for tests, CI, and
offline SDKs. They do not affect later loading of a vendored
`gdalraster`.

## Plumbing API

Use the lower-level functions when setup must be split:

``` r

gdalraster.windows::gdal_install_runtime()
gdalraster.windows::gdal_build_gdalraster()
gdalraster.windows::gdal_enable_python()
gdalraster.windows::gdal_verify()
```

[`gdal_install_runtime()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_install_runtime.md)
is idempotent. A matching `Bundle-Tag` in `MANIFEST.dcf` is skipped. A
newer release is reported without destructive replacement;
[`gdal_update()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_update.md)
or `force = TRUE` performs replacement.

[`gdal_build_gdalraster()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_build_gdalraster.md)
stages a complete package before replacing an existing installation. If
the destination is locked, the old package remains unchanged.

## Provenance and staleness

The runtime manifest records:

- bundle tag and GDAL version;
- release asset name;
- installation time; and
- installer package version.

The build manifest records the bundle tag and GDAL version plus R,
platform, compiler, build time, and builder package version.
[`gdal_sitrep()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_sitrep.md)
compares the two tags. A mismatch means `gdalraster` must be rebuilt.

## Embedded Python

Some algorithms, including `gdal driver gpkg validate`, embed CPython
and import `osgeo_utils`.
[`gdal_enable_python()`](https://docs.jimbrig.com/gdalraster.windows/reference/gdal_enable_python.md)
writes a managed file named `gdalraster-windows-osgeo-utils.pth` into
system CPython’s `site-packages`. The file points at the vendored
`gdalraster/python` directory.

This design does not set `PYTHONPATH`, does not modify user or machine
environment variables, and does not affect isolated virtual
environments. When no system CPython is available, core `gdalraster`
remains usable and the Python-specific check is reported as unavailable.

## Updates

``` r

gdalraster.windows::gdal_update()
```

An update replaces the SDK, rebuilds from source, re-vendors every
runtime component, re-points the managed `.pth`, and verifies in a fresh
process.

For an isolated installation:

``` r

gdalraster.windows::gdal_update(isolated = TRUE)
```

## Uninstall

``` r

gdalraster.windows::gdal_uninstall(force = TRUE)
```

The uninstall removes the selected package from `.libPaths()[1]`, the
SDK, and the managed Python path file. Pass `isolated = TRUE` when the
managed build was placed in the isolated library.

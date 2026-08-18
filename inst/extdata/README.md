Optional packaged fallback runtime asset location.

If you want `gdal_install_runtime()` / `gdal_setup()` to have an offline
fallback, place:

- `gdal-ucrt64-fallback.zip`

in this directory before building/installing the package.

At runtime, the installer uses this file only when:

- `local_zip` is not supplied, and
- release download fails, and
- the fallback zip exists.

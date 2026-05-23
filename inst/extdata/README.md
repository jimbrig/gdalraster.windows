Optional packaged fallback runtime asset location.

If you want `install_gdal_runtime()` to have an offline fallback, place:

- `gdal-ucrt64-fallback.zip`

in this directory before building/installing the package.

At runtime, `install_gdal_runtime()` will use this file only when:

- `local_zip` is not supplied, and
- release download fails, and
- fallback zip exists.

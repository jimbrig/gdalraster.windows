# `tools/`

Canonical CI scripts:

- `build_gdal.sh`: builds GDAL from source in MSYS2 UCRT64.
- `collect_dlls.sh`: assembles the self-contained runtime bundle (`bin`, `include`, `lib`, `share`, `python`) and enforces dependency closure — any non-Windows-system DLL left unresolved fails the build.

Bundle contract (asserted by `.github/workflows/build.yml`):

- `bin/libgdal-*.dll` plus all non-Windows transitive dependency DLLs
- `share/gdal` and `share/proj` runtime data
- `python/osgeo_utils` (pure-python, for embedded-python algorithms)
- `include/` headers and `lib/` import libraries for compiling `gdalraster` against the bundle

No executables ship in the bundle (`BUILD_APPS=OFF`).

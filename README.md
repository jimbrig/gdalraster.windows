# gdalraster.windows

> [!NOTE]
> *Self-Contained [GDAL](https://gdal.org/) Windows runtime with `muparser` enabled for use with [`gdalraster`](https://github.com/firelab/gdalraster) in R.*

<!--badges:start-->

<!--badges:end-->

## What is this?

This repository provides:

1. A [GitHub Action Workflow Build Pipeline](.github/workflows/build.yml) that compiles GDAL from source in MSYS2 UCRT64 with `GDAL_USE_MUPARSER=ON` enabled and static GCC/stdc++ runtime, producing a fully self-contained DLL bundle that does not require libgcc/libstdc++ from Rtools or any other MSYS2 install.

2. An R wrapper package: `gdalraster.windows` that ships those DLLs in `inst/gdal/bin` and loads them at package startup via `.onLoad` so `gdalraster` built against this GDAL works without manual RTools45/MSYS2 configuration or manipulation.

 
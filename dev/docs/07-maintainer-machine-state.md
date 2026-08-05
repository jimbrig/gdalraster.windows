# Maintainer machine state (DESKTOP-MSI)

> Non-normative scratch context (see AGENTS.md documentation hierarchy).
> Snapshot of Jimmy's machine after the 2026-08-04 cleanup session. This
> replaces the old "repeat to AI every session" context about .Rprofile
> hooks, C:/gdal-ucrt64, and custom gdalraster builds — all of that is gone.

## current working state

- **gdalraster (working copy)**: `C:/Users/jimmy/AppData/Local/R/win-library/4.6/gdalraster`
  - built from source by gdalraster.windows against bundle gdal-v3.13.1,
    then manually *vendored*: all bundle `bin/*.dll` copied into
    `libs/x64/`, bundle `share/gdal` + `share/proj` copied over the
    package's `gdal/` + `proj/` dirs (replacing the Rtools-sourced data
    that upstream `Makevars.win` `winlibs` puts there).
  - fully self-contained: plain `library(gdalraster)` works in any session
    with no PATH entries, no env vars, no .Rprofile logic. R's
    `library.dynam()` `DLLpath` (SetDllDirectory) resolves the vendored DLL
    chain and outranks PATH.
- **GDAL runtime bundle (build-time SDK)**: `C:/Users/jimmy/AppData/Roaming/R/data/R/gdalraster.windows/gdal`
  (gdal-v3.13.1). Kept for rebuilds; nothing references it at session time
  except the .pth below.
- **embedded python**: `C:/Python313/Lib/site-packages/gdalraster-windows.pth`
  contains the bundle's `python/` dir, so the interpreter GDAL embeds
  (C:/Python313, first python.exe on PATH; also QUARTO_PYTHON and RStudio's
  interpreter) imports `osgeo_utils` with no env vars. uv envs are isolated
  from system site-packages and unaffected. `PYTHONNOUSERSITE=1` is set
  machine-wide, so user site-packages is NOT an option here.

## removed residue (2026-08-04)

- `.Rprofile` GDAL block (ensure_gdal_runtime + setHook packageEvent hook):
  deleted; archived at `~/.config/R/.Rprofile.gdalraster`.
- `C:/gdal-ucrt64/bin` PATH entry removed from `~/.config/R/.Renviron`
  (rtools45 entries kept).
- `C:/gdal-ucrt64/` (old custom GDAL 3.13.0): archived to external drive,
  removed from C:.
- Old user-library gdalraster (bound to C:/gdal-ucrt64) and the temporary
  `win-library/temp` staging library: deleted.

## other GDALs on this machine (expected, harmless)

- pixi CLI gdal (`C:/Users/jimmy/.pixi/bin/gdal.exe`, MSVC): exe-only on
  PATH, never participates in R DLL resolution.
- Rtools45 static GDAL: used only by CRAN-binary spatial packages
  (statically linked), no DLL collisions possible.

## known caveats

- `update.packages()` / `install.packages("gdalraster")` will clobber the
  vendored build with the CRAN binary (Rtools GDAL, no algorithm API).
  Fix: rebuild via gdalraster.windows.
- Python upgrade/relocation (e.g. 3.14): the .pth does not carry over;
  embedded-python algorithms degrade to ModuleNotFoundError until a new
  .pth is provisioned in the new interpreter's site-packages.
- PYTHONPATH is read at Py_Initialize, which GDAL triggers lazily at the
  FIRST embedded-python algorithm call; setting it later in the process
  does nothing.

## relation to the redesign

The manual vendoring above is the prototype for the self-contained
redesign plan (`.cursor/plans/self-contained_gdalraster_redesign_*.plan.md`):
`gdal_setup()` automates build + vendor + .pth provisioning, and
`gdal_sitrep()` detects the caveats listed here (CRAN clobber, stale
runtime, missing/stale .pth, foreign libgdal on PATH).

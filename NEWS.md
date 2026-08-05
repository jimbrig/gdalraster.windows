# gdalraster.windows 0.3.1

## Package

- `install_gdalraster()` now checks for a working Rtools toolchain up front (`pkgbuild::has_build_tools()`) and aborts with installation guidance when none is found, instead of failing mid-compile with a raw make/gcc error. Rtools is documented as the one prerequisite the prebuilt runtime bundle cannot eliminate — in the README, the Getting Started vignette, and the `install_gdalraster()` help page (which also gains an Upgrading section: rebuild gdalraster after every runtime bundle upgrade).

## GDAL runtime bundle

- Fixed the bundle-wide `LoadLibrary failure: A dynamic link library (DLL) initialization routine failed` (Windows error 1114) that made published bundles unloadable on machines without Rtools' UCRT64 tree. Root cause: the MSYS2 `libpodofo.dll` (PDF driver backend) fails its `DllMain`-time OpenSSL initialization against the MSYS2 `libcrypto-3-x64.dll`. The PDF driver is now disabled outright (`GDAL_ENABLE_DRIVER_PDF=OFF` plus the poppler/podofo/pdfium backends).
- HDF5 and NetCDF drivers are enabled again; the earlier theory that their OpenBLAS/Fortran dependency chain conflicts with R's own DLLs was disproven empirically (every DLL in that chain loads cleanly inside R).
- Bundle verification now has three layers: dependency closure (`ntldd` walk plus a banned-DLL guard for PDF/NSS chains in `collect_dlls.sh`), loadability (every bundled DLL is `LoadLibrary`-tested in CI before an asset can publish), and functionality (the e2e workflow runs on every published bundle release).

## Fixes

- `install_gdalraster()` now replaces the installed package's `gdal/` and `proj/` data directories with the runtime bundle's `share/gdal` and `share/proj` after the source install succeeds (#25). Upstream gdalraster's `Makevars.win` populates those directories from the Rtools static tree, so builds compiled against the bundle GDAL previously shipped — and activated via `GDAL_DATA`/`proj_search_paths()` — data files from a different GDAL/PROJ version.
- `install_gdal_runtime(overwrite = TRUE)` no longer fails with a spurious "locked by another process" error when the *current* session holds the locks. The auto-bootstrap preloads the runtime at package load and prepends its `bin` to `PATH`, so DLLs loaded later in the session resolve dependencies from the runtime directory by module name — the release download itself loads the curl package, which maps the runtime's `zlib1.dll` outside R's DLL registry, where `dyn.unload()` cannot release it. The session therefore could never delete its own runtime. Leftover mapped DLLs are now moved aside into a stale sibling directory (`<gdal_home>.stale-<pid>-<timestamp>`) — Windows allows renaming, though not deleting, mapped DLLs — and the install proceeds; stale directories are deleted opportunistically by later installs, and the installer advises an R restart before rebuilding or loading `gdalraster`.
- `install_gdal_runtime(tag = "latest")` no longer trusts GitHub's single "latest release" pointer, which broke the default install path whenever an R package release (`v*`, no bundle asset) was marked latest. "latest" now scans the release list and selects the newest non-draft, non-prerelease release that publishes a runtime bundle asset matching `asset_pattern`, decoupling the package release track from the GDAL bundle release track.
- GitHub API requests are now authenticated when a token is available — resolved from the git credential store (`gitcreds`), then the `GITHUB_PAT` and `GITHUB_TOKEN` environment variables — avoiding anonymous rate limits in CI and behind shared networks. Release-asset selection also tolerates assets with a missing `name` field.

# gdalraster.windows 0.3.0

## Documentation

- All vignettes migrated from R Markdown (`knitr::rmarkdown`) to Quarto
  (`quarto::html`); `VignetteBuilder` is now `quarto`.
- New "Getting Started" vignette covering the full
  install → build → load → verify workflow, everyday use, install
  locations and overrides, and offline installation.
- "Runtime Guide" rewritten around the current API: `gdal_home` resolution
  order, session activation, auto-bootstrap options
  (`gdalraster.windows.auto_bootstrap`,
  `gdalraster.windows.auto_load_gdalraster`), source builds against the
  bundle, managed `.Rprofile` hooks, embedded-python algorithms, and
  runtime upgrades.
- "Architecture" claims verified against upstream sources (GDAL 3.12.2
  registration fix, Rtools45 release 6768 muparser addition, PE/COFF
  export-ordinal limit); corrected the bundle layout description — no
  executables ship in the bundle (`BUILD_APPS=OFF`).
- Extensive linking across README and vignettes: toolchain components
  (MinGW-w64, MSYS2, UCRT64, Rtools45), GDAL/PROJ/driver references,
  upstream issues, and build scripts. The README package guide now points
  at the pkgdown-hosted articles.
- `install_gdalraster()` and the runtime guide document installing the
  source build into the regular user library via the existing `lib`
  argument (e.g. `lib = .libPaths()[1]`).
- Troubleshooting vignette covers dependency DLLs that resolve in CI but
  not on user machines, and runtime deletion blocked by file locks.

## pkgdown site

- Themed site with branded colors, dark navbar, hex logo, and favicons.
- Articles navbar menu and reference section descriptions.

## Package

- `gdalraster` remains declared in `Suggests` as a soft, conditionally-used
  dependency, but development tooling no longer requires it to be installed
  (attachment config: `pkg_ignore` + `extra.suggests` +
  `check_if_suggests_is_installed: no`). The package's own installer
  (`install_gdalraster()`) is the supported way to provision it.
- Reproducible hex logo generation script (`dev/scripts/pkg_logo.R`).

## Fixes

- The GDAL CI build no longer links `libgdal` against the proprietary
  Microsoft ODBC Driver for SQL Server (`msodbcsql17.dll`), which GitHub
  runner images ship in `System32` but end-user machines typically lack —
  previously this made the published bundle fail to load
  (`LoadLibrary failure`) on machines without that driver
  (`GDAL_USE_MSSQL_ODBC=OFF`, `GDAL_USE_MSSQL_NCLI=OFF`). Bundle
  verification in `tools/collect_dlls.sh` now rejects known non-OS
  `System32` DLLs so this class of runner-image leak fails CI instead of
  shipping (#13).
- `activate_gdal_runtime()` now fails loudly when preloading
  `libgdal-*.dll` fails, with the DLL path and a troubleshooting pointer,
  instead of silently swallowing the error and deferring it to
  `library(gdalraster)` where Windows reports only a generic
  "module could not be found".
- `install_gdal_runtime()` overwrite handling is now robust to DLL file
  locks: the destination check happens before any download, the current
  session's own preloaded runtime DLLs (from the load-time auto-bootstrap)
  are released before deletion, reinstalling while `gdalraster` is loaded
  aborts up front with restart guidance, and deletion is verified so a
  runtime locked by another process aborts cleanly instead of leaving a
  half-deleted install behind.
- `load_gdalraster()` validates the gdalraster library path before
  activating the runtime, so a missing source build errors immediately.
- `verify_gdalraster_runtime()` returns `FALSE` (with a message) when
  runtime activation fails, instead of erroring.

# gdalraster.windows 0.2.1

## Fixes

- `install_gdalraster()` now passes `repos = NULL` to
  `utils::install.packages()` when installing from a local source tarball.
  Previously, `repos` was set to the active CRAN mirror, which caused R to
  treat the tarball path as a package name to look up remotely rather than a
  local file to install. The symptom was a silent no-op accompanied by the
  warning "package '…tar.gz' is not available for this version of R", followed
  by the error "gdalraster source install did not produce an installed
  package" (#11).
- When `upgrade = TRUE`, R package dependencies are now installed via a
  separate `install.packages("gdalraster", repos = repos)` call before the
  source build, so CRAN-resolution still works for the upgrade case while the
  tarball install itself always uses `repos = NULL`.

# gdalraster.windows 0.2.0

## Documentation

- Technical documentation promoted to published vignettes:
  `vignette("architecture")` (toolchain, ABI, DLL loading, embedded python,
  bundle reproduction) and `vignette("troubleshooting")` (triage flow and
  symptom matrix). These are now the canonical docs; `dev/docs/` is
  explicitly non-normative maintainer notes.

## Fixes

- `tools/build_gdal.sh` discovers the produced `libgdal-*.dll` by glob in its
  final verification instead of hardcoding the SONAME, and fails loudly when
  no DLL is produced (#2).
- `install_gdal_runtime()` now emits actionable guidance on download failure:
  the releases URL and the `local_zip` offline install path (#5).

## Build

- GDAL runtime baseline bumped to 3.13.1 (upstream release 2026-06-05);
  default `gdal_version` in the build workflow updated accordingly.

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

<!-- CHECKPOINT id="ckpt_mr5nqr3t_xizns8" time="2026-07-04T01:02:23.417Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->

<!-- CHECKPOINT id="ckpt_mr5o3m2m_haj1ep" time="2026-07-04T01:12:23.422Z" note="auto" fixes=0 questions=0 highlights=0 sections="" -->

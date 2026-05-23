# gdalraster.windows

[![Build GDAL + gdalraster (Windows)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/build.yml)
[![Generate Changelog](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml/badge.svg)](https://github.com/jimbrig/gdalraster.windows/actions/workflows/changelog.yml)

> [!NOTE]
> Self-contained [GDAL](https://gdal.org/) runtime tooling for Windows. Primary output is a portable GDAL runtime bundle; companion R helpers are secondary and may evolve.

## What this project does

`gdalraster.windows` is primarily a Windows GDAL build and distribution effort. The main goal is a reproducible, portable GDAL runtime bundle with reliable algorithm support.

Historically, empty `gdalraster::gdal_global_reg_names()` behavior in Rtools-linked builds was primarily tied to upstream static registration behavior (fixed in GDAL 3.12.2), while muparser support was a separate track that affects expression capabilities and related workflows.

This repository provides:

1. A CI build and packaging pipeline that compiles GDAL from source in MSYS2 UCRT64 with explicit build/link controls (including `GDAL_USE_MUPARSER=ON` and static runtime linker flags).
2. A portable GDAL bundle assembly flow (`bin`, `include`, `lib`, `share`) with transitive DLL collection and dependency checks.
3. A small companion R package (`gdalraster.windows`) to streamline portability with helpers to:
   - locate/configure runtime install path,
   - download a runtime zip from GitHub releases,
   - activate runtime paths and env vars in-session,
   - verify `gdalraster` can see the algorithm registry.

## Current runtime model

The current package API is oriented around a runtime installed to user data (default under `tools::R_user_dir("gdalraster.windows", "data")`), then activated at load-time/session-time.

Earlier prototype work under `dev/temp` explored a bundled `inst/gdal` delivery model (`gdal.win` naming); those notes remain as implementation history and troubleshooting references.

## Upstream context

The current workflow is informed by three related upstream tracks:

1. `gdalraster` Windows algorithm registry issue and diagnosis in [firelab/gdalraster#826](https://github.com/firelab/gdalraster/issues/826).
2. Rtools/MXE muparser enablement work in [firelab/gdalraster#858](https://github.com/firelab/gdalraster/issues/858).
3. Confirmed custom GDAL 3.13 Windows path and runtime hardening notes in [firelab/gdalraster#982](https://github.com/firelab/gdalraster/issues/982).

Related upstream changes:

- [OSGeo/gdal#13592](https://github.com/OSGeo/gdal/pull/13592) removed static registration of top-level algorithms and was backported to GDAL 3.12.2.
- [Rtools45 release notes](https://cran.r-project.org/bin/windows/Rtools/rtools45/news.html) document that muparser was added and enabled for GDAL in release 6768.
- [mxe/mxe#3277](https://github.com/mxe/mxe/pull/3277) updated muparser to 2.3.5.
See [dev/docs/01-overview.md](dev/docs/01-overview.md) for the concise upstream snapshot and project boundaries.

## Quick start (Windows)

### primary path: runtime bundle

1. Build via [`.github/workflows/build.yml`](.github/workflows/build.yml) (manual dispatch or `gdal-v*` tag push).
2. Download the runtime bundle zip artifact/release asset.
3. Use the bundled runtime artifact for downstream package build/runtime verification.

### secondary path: companion R helpers

The R helper API is intentionally lightweight and may change as runtime distribution stabilizes. Current usage is documented in [dev/docs/04-r-runtime-api.md](dev/docs/04-r-runtime-api.md).

## CI and release flow

The main workflow is [`.github/workflows/build.yml`](.github/workflows/build.yml):

- **job 1 (`build-gdal`)**: build GDAL from source, assemble and verify bundle, upload artifact, optionally publish runtime zip on tag.
- **job 2 (`build-r-package`)**: use bundle to compile `gdalraster` and this package into Windows binaries, run smoke checks, upload/release zips.

Trigger modes:

- `workflow_dispatch` for manual builds.
- tag push matching `gdal-v*` for release publication.

## Key files and directories

- [`tools/build_gdal.sh`](tools/build_gdal.sh): source build script for GDAL.
- [`tools/collect_dlls.sh`](tools/collect_dlls.sh): dependency walk and bundle assembly.
- [`.github/workflows/build.yml`](.github/workflows/build.yml): end-to-end CI pipeline.
- [`R/`](R): companion runtime helper package (secondary layer).
- [`dev/temp/`](dev/temp): historical notes, prototype workflows, transcripts, and runbooks.
- [`dev/docs/`](dev/docs): curated architecture and operations documentation for maintainers.

## Documentation map

Start with [`dev/docs/README.md`](dev/docs/README.md) for curated maintainers docs:

- project overview and decisions,
- CI/release mechanics,
- runtime API usage,
- troubleshooting guidance.

## Project status

The GDAL build and bundling pipeline is the core effort. Ongoing work is tightening consistency between:

- package name and release asset naming,
- runtime delivery model details across docs and workflow comments,
- final end-user install guidance for stable Windows setup.

 
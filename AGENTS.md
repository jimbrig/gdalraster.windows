# AGENTS.md

## repo mission

`gdalraster.windows` builds and distributes a Windows GDAL runtime for reliable `gdalraster` algorithm usage, and provides R helpers to install, activate, and verify that runtime.

## high-priority outcomes

1. keep Windows runtime activation reliable (`PATH`, `GDAL_DATA`, `PROJ_LIB`, `PROJ_DATA`, `libgdal-39.dll` loadability)
2. keep CI outputs reproducible and release-ready
3. keep docs aligned with actual runtime model and package/API behavior

## stable focus areas

- CI workflow for GDAL build, bundle assembly, and release artifacts
- build and bundling scripts for dependency closure checks
- companion runtime activation helpers in the R package
- curated docs in [`dev/docs/`](dev/docs) as the canonical narrative layer

## working conventions

- prefer small, focused documentation or code updates that keep naming and behavior consistent across workflow, package, and README
- do not assume prototype `gdal.win` content under `dev/temp` is current production behavior
- when changing runtime behavior, update [`README.md`](README.md) and relevant files under [`dev/docs/`](dev/docs) in the same change
- keep comments sparse and practical
- avoid destructive git operations unless explicitly requested

## r development guidance

- prefer modern package-style R with explicit namespacing (`pkg::fn()`) outside base functions
- use `cli` for user-facing messages and errors (`cli::cli_alert_*()`, `cli::cli_abort()`)
- use `rlang` call context in validations/errors when helpful (`rlang::caller_env()`, `rlang::caller_arg()`)
- use `withr` for temporary env/options/path state in tests and helpers; avoid leaking session state
- keep startup/runtime behavior explicit and reversible (path/env changes should be deliberate and scoped)
- favor small, testable helper functions over long procedural setup blocks

## evidence discipline

- treat issue comments and drafts as claims, not facts, until cross-checked
- separate root cause from parallel contributors (for this project: algorithm registry static-registration bug vs muparser availability)
- prefer primary sources for assertions:
  - upstream issue/PR threads
  - release notes
  - official docs
- if a claim is uncertain, label it as provisional rather than definitive

## validation checklist after substantive changes

- verify references to package name are `gdalraster.windows` unless intentionally describing historical prototype content
- if CI/build logic is changed, sanity-check docs in [`README.md`](README.md) and [`dev/docs/`](dev/docs)
- if runtime helper behavior changes, verify docs still describe current behavior without over-specifying internal implementation

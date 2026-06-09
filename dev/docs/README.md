# dev docs

> [!IMPORTANT]
> These are non-normative maintainer/agent working notes. The canonical,
> published documentation lives in [`vignettes/`](../../vignettes) (rendered
> on the pkgdown site) and in the roxygen help pages. When these notes and
> the vignettes disagree, the vignettes and code win. Agents should update
> vignettes/roxygen for any user-facing behavior change; updating these notes
> is optional.

Canonical published docs:

- `vignettes/runtime-guide.Rmd` — install/activate/load user guide
- `vignettes/architecture.Rmd` — toolchain, ABI, DLL loading, embedded
  python, bundle reproduction
- `vignettes/troubleshooting.Rmd` — triage flow and symptom matrix

## Recommended reading order (these notes)

1. [`01-overview.md`](01-overview.md)
2. [`06-toolchain-and-abi.md`](06-toolchain-and-abi.md)
3. [`02-runtime-model.md`](02-runtime-model.md)
4. [`03-ci-and-release.md`](03-ci-and-release.md)
5. [`04-r-runtime-api.md`](04-r-runtime-api.md)
6. [`05-troubleshooting.md`](05-troubleshooting.md)

## Scope of these docs

- Keep notes implementation-anchored and general.
- Prefer references to code and upstream sources over narrative speculation.
- Avoid session-specific conclusions in core maintainer docs.

## Archive material

Historical reconstruction notes (e.g. `07-*`) are retained for reference and
debugging context, but they are not normative project guidance.

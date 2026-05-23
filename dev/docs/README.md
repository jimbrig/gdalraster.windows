# dev docs

This directory contains curated maintainers documentation for `gdalraster.windows`.

Use this as the canonical narrative layer for how the repository works today. Historical context and prototypes still live in `dev/temp/`, but should not be treated as source-of-truth without confirmation.

## quality bar

- keep docs short and operational
- avoid duplicated explanations across files
- keep cause/effect language precise and evidence-backed
- label uncertain statements as provisional

## document index

- [`01-overview.md`](01-overview.md): mission, architecture boundaries, and upstream status snapshot
- [`03-ci-and-release.md`](03-ci-and-release.md): GitHub Actions workflow, release artifacts, and drift checks
- [`04-r-runtime-api.md`](04-r-runtime-api.md): exported R API and minimal usage flow
- [`05-troubleshooting.md`](05-troubleshooting.md): operational triage for compile/install/runtime failures

## how to keep this current

- when runtime behavior changes, update [`04-r-runtime-api.md`](04-r-runtime-api.md) and [`05-troubleshooting.md`](05-troubleshooting.md)
- when CI/release logic changes, update [`03-ci-and-release.md`](03-ci-and-release.md)
- when architecture/naming direction changes, update [`01-overview.md`](01-overview.md)

#  ------------------------------------------------------------------------
#
# Title : GitHub Labels
#    By : Jimmy Briggs
#  Date : 2026-07-03
#
#  ------------------------------------------------------------------------

gh_labels <- tibble::tibble(
  name = c(
    "feature",
    "release",
    "refactor",
    "tests",
    "documentation",
    "maintenance",
    "build",
    "cicd",
    "dependencies",
    "bug",
    "tools",
    "investigation",
    "upstream"
  ),
  description = c(
    feature = "New feature or enhancement",
    release = "Release or version bump",
    refactor = "Code change that neither fixes a bug nor adds a feature",
    tests = "Adding or updating tests",
    documentation = "Documentation related tasks",
    maintenance = "Maintenance related tasks",
    build = "Build related tasks",
    cicd = "CI/CD related tasks",
    dependencies = "Dependency related tasks",
    bug = "Bug related tasks",
    tools = "Tool related tasks",
    investigation = "Needs investigation or root-cause analysis",
    upstream = "Tracks upstream projects (GDAL, Rtools, gdalraster)"
  ),
  color = c(
    feature = "0e8a16",
    release = "fbca04",
    refactor = "1d76db",
    tests = "bfe5bf",
    documentation = "5319e7",
    maintenance = "f9d0c4",
    build = "c2e0c6",
    cicd = "1d76db",
    dependencies = "0e8a16",
    bug = "d73a4a",
    tools = "bfe5bf",
    investigation = "e99695",
    upstream = "0052cc"
  )
)

usethis::use_github_labels(
  labels = gh_labels$name,
  colours = gh_labels$color,
  descriptions = gh_labels$description,
  delete_default = FALSE
)

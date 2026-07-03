
#  ------------------------------------------------------------------------
#
# Title : Package Documentation
#    By : Jimmy Briggs
#  Date : 2026-07-03
#
#  ------------------------------------------------------------------------

# initialize ------------------------------------------------------------------------------------------------------

# gdalraster is a soft dependency: declared in Suggests (extra.suggests) but
# never required to be installed locally (pkg_ignore +
# check_if_suggests_is_installed = FALSE) since this package builds its own
# gdalraster from source into an isolated library.
attachment::att_amend_desc(
  pkg_ignore = "gdalraster",
  extra.suggests = "gdalraster",
  update.config = TRUE,
  check_if_suggests_is_installed = FALSE
)

# subsequent runs restore these parameters from dev/config_attachment.yaml:
# attachment::att_amend_desc()

# vignettes -------------------------------------------------------------------------------------------------------

usethis::use_vignette("getting-started.qmd", "Getting Started")
usethis::use_vignette("architecture.qmd", "Architecture")
usethis::use_vignette("runtime-guide.qmd", "Runtime Guide")
usethis::use_vignette("troubleshooting.qmd", "Troubleshooting")

# pkgdown ---------------------------------------------------------------------------------------------------------

usethis::use_pkgdown_github_pages()

# NEWS ------------------------------------------------------------------------------------------------------------

usethis::use_news_md()

# changelog -------------------------------------------------------------------------------------------------------

fs::file_create("CHANGELOG.md")
usethis::use_build_ignore("CHANGELOG.md")

# desc ------------------------------------------------------------------------------------------------------------

desc::desc_normalize()

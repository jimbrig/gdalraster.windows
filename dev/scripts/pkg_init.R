
#  ------------------------------------------------------------------------
#
# Title : package initialization
#    By : Jimmy Briggs
#  Date : 2026-05-23
#
#  ------------------------------------------------------------------------

require(usethis)

usethis::create_package(getwd())
usethis::use_directory("dev", ignore = TRUE)
usethis::use_directory(".cursor", ignore = TRUE)
usethis::use_directory(".github/workflows", ignore = TRUE)
usethis::use_directory("tools", ignore = TRUE)
# fs::file_create("tools/config.R")
# fs::file_create("tools/msrv.R")
# fs::file_create("configure.win")
# fs::file_create("cleanup.win")
fs::file_create("CHANGELOG.md")
fs::file_create(".github/workflows/changelog.yml")

fs::dir_create("inst")
# fs::dir_create("inst/bin")
# fs::dir_create("inst/config")
# fs::dir_create("inst/scripts")
# fs::dir_create("inst/lib")
# fs::dir_create("inst/extdata")

usethis::use_namespace()
usethis::use_roxygen_md()
attachment::att_amend_desc()

usethis::use_build_ignore(".Renviron")
usethis::use_build_ignore(".Rprofile")
usethis::use_build_ignore(".gitattributes")
usethis::use_build_ignore(".editorconfig")
usethis::use_build_ignore("AGENTS.md")
usethis::use_build_ignore(".cursorignore")
usethis::use_build_ignore(".repomixignore")
usethis::use_build_ignore("repomix.config.json")
usethis::use_build_ignore("CHANGELOG.md")

usethis::use_air()
usethis::use_make()

usethis::use_package_doc()
usethis::use_r("aaa.R")
usethis::use_r("zzz.R")
usethis::use_r("utils_pkg.R")

# could be useful:
# usethis::use_zip()

# not sure if needed/what approach to take yet:
# usethis::use_cpp11()
# usethis::use_rcpp()
# usethis::use_c()
# rextendr::use_extendr()

# usethis::edit_r_makevars()

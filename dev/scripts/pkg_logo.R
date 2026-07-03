
#  ------------------------------------------------------------------------
#
# Title : Package Logo
#    By : Jimmy Briggs
#  Date : 2026-07-03
#
#  ------------------------------------------------------------------------

require(curl)
require(magick)
require(hexSticker)
require(showtext)
require(this.path)
require(purrr)

# download images -------------------------------------------------------------------------------------------------

man_figures_path <- file.path(this.path::this.proj(), "man/figures")
if (!dir.exists(man_figures_path)) dir.create(man_figures_path)

img_urls <- c(
  "gdal_favicon_png" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/favicon.png",
  "gdal_icon_small" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/gdalicon.png",
  "gdal_icon_big" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/gdalicon_big.png",
  "gdal_logo_svg_bw" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/logo/GDALLogoBW.svg",
  "gdal_logo_svg_color" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/logo/GDALLogoColor.svg",
  "gdal_logo_svg_gs" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/logo/GDALLogoGS.svg",
  "osgeo_logo_svg" = "https://raw.githubusercontent.com/OSGeo/gdal/1b7c6d1ec43dda828f6041b4edc019b0c9cce8bc/doc/images/logo-osgeo.svg",
  "osgeo_logo_png" = "https://raw.githubusercontent.com/OSGeo/gdal/refs/heads/master/doc/images/logo-osgeo.png"
)

purrr::walk2(
  .x = img_urls,
  .y = names(img_urls),
  .f = function(url, name) {
    name <- if (grepl("_png$", name)) gsub("_png$", "", name) else name
    name <- if (grepl("_svg$", name)) gsub("_svg$", "", name) else name
    dest <- file.path(man_figures_path, paste0(name, ".", tools::file_ext(url)))
    curl::curl_download(url, destfile = dest)
    cli::cli_alert_success("Downloaded {.url {url}} to {.file {dest}}")
  },
  .progress = TRUE
)


# set pkgdown favicon ---------------------------------------------------------------------------------------------

# using the GDAL favicon instead of the hex logo, need to first temporarily set the project logo to be GDAL
usethis::use_logo("man/figures/gdal_favicon.png")
pkgdown::build_favicons(overwrite = TRUE)
file.rename("man/figures/logo.png", "man/figures/logo_gdal.png")

# create hex logo -------------------------------------------------------------------------------------------------

hex_img <- "man/figures/gdal_icon_big.png"

# set font
font_add_google("Ubuntu", "ubuntu")
showtext_auto()

# png ---------------------------------------------------------------------

hexSticker::sticker(
  filename = "man/figures/hex.logo.png",
  # package name
  package = pkgload::pkg_name(),
  p_x = 1,
  p_y = 1.4,
  p_color = "white",
  p_family = "ubuntu",
  p_fontface = "plain",
  p_size = 4,
  # image
  subplot = hex_img,
  s_x = 1,
  s_y = 0.8,
  s_width = 0.5,
  s_height = 1,
  asp = 0.9,
  dpi = 600,
  # hexagon
  h_size = 1.2,
  h_fill = "black",
  h_color = "cyan",
  # url
  url = "github.com/jimbrig/gdalraster.windows",
  u_x = 1,
  u_y = 0.08,
  u_color = "cyan",
  u_family = "ubuntu",
  u_size = 1.2,
  u_angle = 30
)

# svg ---------------------------------------------------------------------

hexSticker::sticker(
  filename = "man/figures/hex.logo.svg",
  # package name
  package = pkgload::pkg_name(),
  p_x = 1,
  p_y = 1.4,
  p_color = "white",
  p_family = "ubuntu",
  p_fontface = "plain",
  p_size = 4,
  # image
  subplot = hex_img,
  s_x = 1,
  s_y = 0.8,
  s_width = 0.5,
  s_height = 1,
  asp = 0.9,
  dpi = 600,
  # hexagon
  h_size = 1.2,
  h_fill = "black",
  h_color = "cyan",
  # url
  url = "github.com/jimbrig/gdalraster.windows",
  u_x = 1,
  u_y = 0.08,
  u_color = "cyan",
  u_family = "ubuntu",
  u_size = 1.2,
  u_angle = 30
)

# set package logo ------------------------------------------------------------------------------------------------

usethis::use_logo("man/figures/hex.logo.png")


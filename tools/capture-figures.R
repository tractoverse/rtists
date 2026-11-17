# Regenerate the static three.js figures embedded in the README.
#
# The README demonstrates plot3d() with the default "threejs" backend. The
# figures are captured from a real widget in a headless browser rather than
# rendered at knit time (a full Chromium is required and the clocked render is
# too slow/raunchy for R CMD check). The committed PNGs under man/figures are
# produced by this script; re-run it to refresh them.
#
# Usage:
#   Rscript tools/capture-figures.R
#
# Requirements (development only, not listed in DESCRIPTION):
#   - R packages: chromote, base64enc, htmlwidgets (the package itself is
#     installed via the standard load-all/devtools flow)
#   - python3 (to serve the widget over HTTP; see below)
#   - a Chrome/Chromium binary discoverable by chromote (and the "chromote"
#     Chrome profile)
#
# Why serve over HTTP? htmlwidgets::saveWidget(..., selfcontained = FALSE)
# writes a loader script with a real src URL; the rtists loader injects an
# import map and dynamically imports the ESM renderer. With the default
# selfcontained = TRUE the loader script is inlined, document.currentScript.src
# is empty, and nothing renders -> serve the widget directory over http and
# point chromote at it.

suppressPackageStartupMessages({
  library(chromote)
  library(fiber)
  library(htmlwidgets)
  library(rtists)
})

.argv <- commandArgs(trailingOnly = FALSE)
.file.arg <- grep("--file=", .argv, value = TRUE)
.src.dir <- if (length(.file.arg)) dirname(sub("^--file=", "", .file.arg)) else "."
root <- normalizePath(file.path(.src.dir, ".."), mustWork = FALSE)

stopifnot(
  "run from the package root or via Rscript tools/capture-figures.R" =
    file.exists(file.path(root, "DESCRIPTION"))
)

out_dir <- file.path(root, "man", "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# ---- helper: render a widget to a canvas-clipped PNG -------------------------

capture_widget <- function(widget, outfile, width = 700, height = 500,
                           scale = 2, port = NULL, pad = 0) {
  if (is.null(port)) {
    port <- 8800 + sample(1:500, 1)
  }
  wd <- file.path(tempdir(), paste0("w-", basename(outfile), "-", port))
  dir.create(wd, showWarnings = FALSE)
  saveWidget(widget, file.path(wd, "index.html"), selfcontained = FALSE)
  system2("python3", c("-m", "http.server", port, "--directory", wd),
          wait = FALSE, stdout = FALSE, stderr = FALSE)
  on.exit(
    system2("pkill", c("-f", paste0("http.server ", port)),
            stdout = FALSE, stderr = FALSE),
    add = TRUE
  )
  on.exit(unlink(wd, recursive = TRUE), add = TRUE)
  Sys.sleep(1.2)
  b <- ChromoteSession$new(width = width, height = height)
  on.exit(b$close(), add = TRUE)
  b$Page$navigate(sprintf("http://127.0.0.1:%d/index.html", port))
  Sys.sleep(3)
  b$Emulation$setDeviceMetricsOverride(
    width = width, height = height, deviceScaleFactor = scale, mobile = FALSE
  )
  Sys.sleep(1.5)
  res <- b$Runtime$evaluate(
    "(() => { const c = document.querySelector('canvas'); \
      const r = c.getBoundingClientRect(); \
      return {x: r.x, y: r.y, w: r.width, h: r.height}; })()",
    returnByValue = TRUE
  )
  rect <- res$result$value
  clip <- list(
    x = rect$x + pad, y = rect$y + pad,
    width = rect$w - 2 * pad, height = rect$h - 2 * pad,
    scale = scale
  )
  shot <- b$Page$captureScreenshot(format = "png", clip = clip,
                                   captureBeyondViewport = TRUE)
  writeBin(base64enc::base64decode(shot$data), outfile)
  invisible(outfile)
}

# ---- the README toy bundle ----------------------------------------------------

pts <- matrix(
  c(
    0, 0, 0,
    1, 2, 1,
    2, 3, 3,
    3, 3, 5,
    4, 2, 6,
    5, 1, 7
  ),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)

sl <- streamline(
  points          = pts,
  point_data      = list(FA = c(0.25, 0.40, 0.65, 0.70, 0.55, 0.30)),
  streamline_data = list(mean_FA = 0.475)
)

set.seed(42)
bun <- bundle(lapply(seq_len(6), function(i) {
  noise <- matrix(rnorm(nrow(pts) * 3, sd = 0.2), ncol = 3)
  colnames(noise) <- c("X", "Y", "Z")
  streamline(
    points          = pts + noise,
    point_data      = list(FA = pmin(pmax(sl@point_data$FA + rnorm(6, sd = 0.05), 0), 1)),
    streamline_data = list(mean_FA = mean(sl@point_data$FA))
  )
}))

# ---- regenerate each figure ----------------------------------------------------

# linewidth 0.05 keeps fibres thin in the ~10-world-unit toy scene (~0.5% of the
# diagonal); the default linewidth = 2 would render as fat blobs.
figs <- list(
  orientation =     plot3d(bun, linewidth = 0.05),
  `point-fa` =      plot3d(bun, color = "FA", palette = "Viridis", linewidth = 0.05),
  `streamline-fa` = plot3d(bun, color = "mean_FA", palette = "RdYlBu", linewidth = 0.05),
  fixed =           plot3d(bun, color = "steelblue", opacity = 0.7,
                           linewidth = 0.05)
)

for (nm in names(figs)) {
  out <- file.path(out_dir, sprintf("README-%s-1.png", nm))
  message("capturing ", nm, " -> ", out)
  capture_widget(figs[[nm]], out)
}

message("done: ", paste(names(figs), collapse = ", "))

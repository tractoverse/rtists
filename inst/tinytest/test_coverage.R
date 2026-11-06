# Branch-coverage tests for the internal helpers and dispatch paths that the
# end-to-end test_plot3d.R does not reach. Run via the source tree:
#   pkgload::load_all("/Users/stamm-a/Softs/rtists")
#   tinytest::run_test_file("inst/tinytest/test_coverage.R")

pts <- matrix(
  c(0, 0, 0,
    1, 1, 0,
    2, 1, 1,
    3, 2, 2,
    4, 3, 2),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)
sl <- fiber::streamline(
  points          = pts,
  point_data      = list(FA = c(0.3, 0.5, 0.7, 0.6, 0.4)),
  streamline_data = list(mean_FA = 0.5)
)
bun <- fiber::bundle(list(sl, sl))

# ================= as_data_frame.R =================

# .bundle_to_df: broadcast scalar bundle_data as extra columns (lines 30-32)
bun2 <- fiber::bundle(list(sl, sl), bundle_data = list(region = "motor"))
df  <- rtists:::.bundle_to_df(bun2)
expect_true("region" %in% names(df))
expect_equal(unique(df$region), "motor")
expect_equal(nrow(df), 10L)

# .bundle_set_to_df (lines 40-59): two bundles, default names = sequence
bs <- fiber::bundle_set(list(bun, bun))
dfbs <- rtists:::.bundle_set_to_df(bs)
expect_equal(nrow(dfbs), 20L)
expect_equal(sort(unique(dfbs$StreamlineId)), 1:4)   # offsets accumulate
expect_equal(sort(unique(dfbs$BundleName)), 1:2)     # default seq_len names

# .bundle_set_to_df: explicit bundle_names override the default sequence
dfbs2 <- rtists:::.bundle_set_to_df(bs, bundle_names = c("x", "y"))
expect_equal(unique(dfbs2$BundleName), c("x", "y"))
expect_equal(sort(unique(dfbs2$StreamlineId)), 1:4)

# .bundle_set_to_df: honors per-bundle input names from a *named* bundle_set.
# fiber::bundle_set(list(foo = b1, bar = b2)) records the names in
# bundle_data$id_from_input_names and then unnames @bundles, so rtists must
# read that slot (lines 43-44) rather than seq_len(). Regression test: the old
# code looked in the wrong slot (@set_attributes) and silently produced 1,2.
bunA  <- fiber::bundle(list(sl, sl))
bunB  <- fiber::bundle(list(sl))
named <- fiber::bundle_set(list(corpus = bunA, callosum = bunB))
ndf   <- rtists:::.bundle_set_to_df(named)
expect_equal(unique(ndf$BundleName), c("corpus", "callosum"))
# per-bundle streamline counts match (2 + 1 = 3 streamlines -> rows sum)
expect_equal(nrow(ndf), sum(vapply(list(bunA, bunB), function(b) b@n_streamlines, 0L)) * nrow(sl@points))

# ================= backend-threejs.R =================

# .df_to_streamlines: single streamline without StreamlineId (line 23)
sl_noid <- data.frame(X = c(0, 1, 2), Y = c(0, 1, 2), Z = c(0, 1, 2))
sls <- rtists:::.df_to_streamlines(sl_noid)
expect_length(sls, 1L)
expect_equal(dim(sls[[1L]]), c(3L, 3L))

# with StreamlineId: one matrix per id, rows ordered by (id, PointId)
df_id <- data.frame(
  StreamlineId = c(2, 2, 1),
  X            = c(0, 1, 7),
  Y            = c(0, 1, 7),
  Z            = c(0, 1, 7)
)
sls2 <- rtists:::.df_to_streamlines(df_id)
expect_length(sls2, 2L)
expect_equal(sls2[[1L]][1L, 1L], 7)   # id 1
expect_equal(sls2[[2L]][1L, 1L], 0)   # id 2

# .df_resolve_colors: color_by_bundle threads a per-bundle category (38-42)
bsdf <- rtists:::.bundle_set_to_df(fiber::bundle_set(list(bun, bun)))
cols <- rtists:::.df_resolve_colors(bsdf, "BundleName", "Viridis",
                                    color_by_bundle = TRUE)
expect_length(cols, length(unique(bsdf$StreamlineId)))
expect_true(is.character(cols))
# every streamline in bundle 1 shares one colour, distinct from bundle 2's
expect_equal(length(unique(cols[unique(bsdf$StreamlineId) %in% 1:2])), 1L)
expect_equal(length(unique(cols[unique(bsdf$StreamlineId) %in% 3:4])), 1L)
expect_false(cols[1L] == cols[3L])

# .df_resolve_colors: "orientation" passes straight through (45-46)
expect_identical(
  rtists:::.df_resolve_colors(df_id, "orientation", "Viridis"),
  "orientation"
)

# .df_resolve_colors: numeric meta -> range-mapped palette (56-61)
dfn <- data.frame(X=1:3, Y=1:3, Z=1:3, StreamlineId=c(1,1,2), val=c(10,10,20))
cols <- rtists:::.df_resolve_colors(dfn, "val", "Viridis")
expect_length(cols, 2L)
expect_false(cols[1L] == cols[2L])   # distinct values -> distinct colours

# .df_resolve_colors: zero-span numeric guarded (58)
dfz <- data.frame(X=1:3, Y=1:3, Z=1:3, StreamlineId=c(1,1,2), val=c(5,5,5))
colsz <- rtists:::.df_resolve_colors(dfz, "val", "Viridis")
expect_equal(colsz[1L], colsz[2L])

# .df_resolve_colors: character/factor meta -> categorical palette (64-67)
dfc <- data.frame(X=1:3, Y=1:3, Z=1:3, StreamlineId=c(1,1,2),
                  grp=c("a","a","b"))
colsc <- rtists:::.df_resolve_colors(dfc, "grp", "Viridis")
expect_length(colsc, 2L)
expect_false(colsc[1L] == colsc[2L])

# .df_resolve_colors: fixed hex/CSS colour recycled (71)
colsf <- rtists:::.df_resolve_colors(dfc, "steelblue", "Viridis")
expect_equal(colsf, rep_len("steelblue", 2L))

# .threejs_radius: scalar radius <= 0 -> thin line2 (104-106)
sol <- rtists:::.threejs_radius(linewidth = 1, thickness = 0, radius = -1,
                                n_pts = c(5, 5))
expect_equal(sol$mode, "line2")
expect_null(sol$radii)

# .threejs_radius: per-streamline non-positive radius errors (129-130)
expect_error(
  rtists:::.threejs_radius(1, 0, c(0.2, -0.3), c(5, 5)),
  "positive"
)
# and wrong-length radius errors (121-126)
expect_error(
  rtists:::.threejs_radius(1, 0, c(0.2, 0.3, 0.4), c(5, 5)),
  "radius"
)

# .threejs_radius: effectively constant per-point -> fast line2 (132-135)
con <- rtists:::.threejs_radius(1, 0, c(0.5, 0.5, 0.5, 0.5, 0.5), n_pts = 5)
expect_equal(con$mode, "line2")
expect_equal(con$linewidth, 0.5)
expect_null(con$radii)

# .threejs_widget: empty streamlines list errors (147-148)
expect_error(rtists:::.threejs_widget(list()), "non-empty")

# tube mode with a fixed colour (non-orientation path, 184-190)
fig <- plot3d(sl, thickness = 0.2, color = "steelblue")
expect_equal(unclass(fig$x$mode), "tube")
expect_true(is.raw(fig$x$colors))

# orientation colormap with a zero-length segment: duplicate consecutive points
# hit the n == 0 fallback (backend-threejs.R:239) rather than dividing by zero
sl_dup <- fiber::streamline(points = cbind(X = c(0, 1, 1, 2),
                                           Y = c(0, 0, 0, 1),
                                           Z = c(0, 0, 0, 1)))
figz <- plot3d(sl_dup)                                # defaults to orientation
expect_equal(unclass(figz$x$mode), "line2")
expect_true(is.raw(figz$x$colors))
expect_length(figz$x$colors, 6L * (nrow(sl_dup@points) - 1L))

# Shiny output / render helpers (no Shiny required to construct)
o <- rtistsOutput("o1")
expect_true(inherits(o, "shiny.tag.list"))
r <- renderRtists(plot3d(sl))
expect_true(is.function(r))

# ================= plot3d.R =================

# .plot3d_impl, plotly backend: numeric metadata -> continuous scale (56-64,86)
fig <- plot3d(bun, backend = "plotly", color = "mean_FA")
expect_inherits(fig, "plotly")
expect_true("colorscale" %in% names(fig$x$attrs[[1L]]$line))

# fixed CSS colour (72)
fig <- plot3d(sl, backend = "plotly", color = "steelblue")
expect_inherits(fig, "plotly")

# char metadata -> discrete (67)
slc <- fiber::streamline(points = pts,
                         streamline_data = list(group = "tractA"))
fig <- plot3d(slc, backend = "plotly", color = "group")
expect_inherits(fig, "plotly")

# no metadata -> hoverinfo "none" (98-99)
sl2 <- fiber::streamline(points = pts)
fig <- plot3d(sl2, backend = "plotly")
expect_inherits(fig, "plotly")

# bundle_set S7 method: threejs (default) + colour-by-bundle (448-476)
bs1 <- fiber::bundle_set(list(bun, bun))
fig <- plot3d(bs1)
expect_inherits(fig, "rtists")
fig <- plot3d(bs1, color_by_bundle = TRUE)
expect_inherits(fig, "rtists")
# bundle_set S7 method, plotly backend
fig <- plot3d(bs1, backend = "plotly")
expect_inherits(fig, "plotly")
fig <- plot3d(bs1, backend = "plotly", color_by_bundle = TRUE)
expect_inherits(fig, "plotly")

# ================= run-example.R =================
# .rtists_source_root() and runExample() are only meaningful from a real source
# checkout: the `demo/` folder they launch is Rbuildignored and never installed,
# so the resolve can only succeed (and `demo/line2/app.R` can only exist) when
# running locally after devtools::load_all(). On R CMD check / CI, where neither
# holds, this whole block is skipped instead of erroring on a developer's
# hard-coded absolute path.
src_root <- tryCatch(rtists:::.rtists_source_root(), error = function(e) NA_character_)
if (!is.na(src_root) && file.exists(file.path(src_root, "demo", "line2", "app.R"))) {
  # .rtists_source_root: resolves the source tree from the repo root
  old <- getwd(); on.exit(setwd(old), add = TRUE)
  setwd(src_root)
  expect_identical(rtists:::.rtists_source_root(), src_root)

  # runExample: unknown demo name errors (demo not found), before any Shiny call
  expect_error(rtists::runExample("does-not-exist"), "Demo app not found")

  # runExample: happy path reaches shiny::runApp() (lines 72-73). Shiny is a
  # Suggests-only dependency, hence the guard.
  if (requireNamespace("shiny", quietly = TRUE)) {
    # Replace shiny::runApp with a no-op so the launcher returns without
    # launching a live app or opening a browser; restore afterwards.
    orig_runApp <- get("runApp", envir = asNamespace("shiny"))
    on.exit(assignInNamespace("runApp", orig_runApp, ns = "shiny"), add = TRUE)
    fake_run <- function(appDir, ...) invisible(NULL)
    assignInNamespace("runApp", fake_run, ns = "shiny")
    expect_identical(withVisible(rtists::runExample("line2"))$value, TRUE)
  }
}

# .onLoad registers S7 methods and must not error (zzz.R:9); it returns NULL
expect_null(rtists:::.onLoad(NULL, "rtists"))

# ================= plotly-not-installed branch (38-42) =================
# requireNamespace() returns TRUE once plotly is *loaded* (and it is, by the
# plotly-backend tests above), regardless of .libPaths(), and R's base namespace
# is locked so it cannot be rebound directly. The check therefore lives behind
# the package-owned helper is_installed() (R/utils.R), which mockthat can mock
# in-process; being in-process, covr tallies lines 38-42.
if (requireNamespace("mockthat", quietly = TRUE)) {
  pts <- cbind(X = c(0, 1, 2), Y = c(0, 1, 1), Z = c(0, 0, 1))
  sl  <- fiber::streamline(points = pts)
  msg <- mockthat::with_mock(
    `rtists::is_installed` = function(pkg) FALSE,
    tryCatch({ rtists::plot3d(sl, backend = "plotly"); "no-error" },
             error = function(e) conditionMessage(e))
  )
  expect_true(grepl("plotly backend requires", msg))
}

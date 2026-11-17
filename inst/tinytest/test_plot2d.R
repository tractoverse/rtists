# 2D arclength-projection plots (plot2d()). ggplot2 is a Suggests-only
# dependency, so the figure assertions are skipped when it is not installed;
# the ggplot2-missing error branch itself is exercised unconditionally via a
# mocked is_installed() (mirroring the plotly branch in test_coverage.R).

pts <- matrix(
  c(0, 0, 0, 1, 1, 0, 2, 1, 1, 3, 2, 2, 4, 3, 2),
  ncol = 3,
  byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)
sl <- fiber::streamline(
  points = pts,
  point_data = list(FA = c(0.3, 0.5, 0.7, 0.6, 0.4)),
  streamline_data = list(mean_FA = 0.5)
)
bun <- fiber::bundle(list(sl, sl))
bs <- fiber::bundle_set(list(
  corpus = bun,
  callosum = fiber::bundle(list(sl))
))

# ---- internal arclength helpers ----------------------------------------------

# cumulative 3D arclength starts at 0, ends at the polyline total
al <- rtists:::.streamline_arclength(pts)
expect_equal(al[1L], 0)
expect_equal(
  al[5L],
  sum(sqrt(rowSums(diff(pts)^2))),
  tolerance = 1e-6
)
# known fixture values: 0, sqrt2, 2*sqrt2, ..., 5.9747
expect_equal(
  al,
  c(0, 1.414213562, 2.828427125, 4.560477932, 5.974691495),
  tolerance = 1e-6
)

# .n_chunks caps: short tracks keep one chunk per point, long ones thin out
expect_equal(rtists:::.n_chunks(5L), 5L)
expect_equal(rtists:::.n_chunks(200L), 25L)
expect_equal(rtists:::.n_chunks(10000L), 1250L)

# .chunk_summary averages numeric columns per chunk, broadcasts scalars, sums
# `.dist` per chunk, records the chunk-start `.arclen`, and drops empty chunks
dfc <- data.frame(
  StreamlineId = 1L,
  PointId = 1:5,
  X = 0:4,
  Y = c(0, 1, 1, 2, 3),
  Z = c(0, 0, 1, 2, 2),
  FA = c(0.3, 0.5, 0.7, 0.6, 0.4),
  mean_FA = 0.5
)
dfc$.arclen <- rtists:::.streamline_arclength(as.matrix(dfc[c("X", "Y", "Z")]))
dfc$.dist <- c(0, diff(dfc$.arclen))
dfc$.chunk <- c(1, 1, 2, 3, 3) # chunk 2 holds a single point; nothing is empty
cs <- rtists:::.chunk_summary(dfc, dfc$.chunk)
expect_equal(nrow(cs), 3L)
expect_equal(cs$FA, c(0.4, 0.7, 0.5)) # per-chunk means
expect_equal(cs$mean_FA, rep(0.5, 3L)) # scalar broadcast unchanged
expect_equal(
  cs$.dist,
  c(1.414213562, 1.414213562, 3.14626437),
  tolerance = 1e-6
)
expect_equal(cs$.arclen, c(0, 2.828427125, 4.560477932), tolerance = 1e-6)
expect_equal(cs$.chunk, 1:3)

# a chunk with no points is dropped rather than erroring
dfg <- dfc
dfg$.chunk <- c(1, 1, 5, 5, 5)
csg <- rtists:::.chunk_summary(dfg, dfg$.chunk)
expect_equal(csg$.chunk, c(1L, 5L))
expect_equal(sum(csg$.dist), sum(sqrt(rowSums(diff(pts)^2))), tolerance = 1e-6)

# ---- ggplot2 required --------------------------------------------------------

if (requireNamespace("ggplot2", quietly = TRUE)) {
  # ggplot2 >= 4.0 stores plot components as S7 properties; a helper keeps the
  # assertions readable across minor-version layout differences.
  .plot_data <- function(p) S7::prop(p, "data")
  .plot_scales <- function(p) S7::prop(p, "scales")$scales
  .plot_layer <- function(p) S7::prop(p, "layers")[[1L]]
  .plot_facet <- function(p) S7::prop(p, "facet")
  .plot_panels <- function(p) {
    as.character(sort(unique(ggplot2::ggplot_build(p)$layout$layout$axis)))
  }

  # ---- return type & facets --------------------------------------------------

  p <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl))
  expect_inherits(p, "ggplot")
  expect_equal(.plot_panels(p), c("X", "Y", "Z")) # 3 stacked coordinate facets
  # one ggplot2::geom_line layer
  expect_true(inherits(.plot_layer(p)$geom, "GeomLine"))
  expect_equal(.plot_layer(p)$aes_params$linewidth, 0.5)
  expect_equal(.plot_layer(p)$aes_params$alpha, 1)

  # a facet subset renders only the requested coordinate
  pX <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl), facet = "X")
  expect_equal(.plot_panels(pX), "X")
  pXY <- rtists:::.plot2d_impl(
    rtists:::.streamline_to_df(sl),
    facet = c("X", "Z")
  )
  expect_equal(.plot_panels(pXY), c("X", "Z"))

  # labels set the shared arclength vocabulary
  lab <- S7::prop(p, "labels")
  expect_identical(lab$x, "Arclength (mm)")
  expect_identical(lab$y, "Coordinate")

  # long-format data: one row per chunk per facet, with `.value` + `axis`
  dat <- .plot_data(p)
  expect_true(all(c(".value", "axis") %in% names(dat)))
  expect_equal(levels(dat$axis), c("X", "Y", "Z"))
  # arclengths are chunk starts, monotonically increasing within each axis
  mon <- all(vapply(
    split(dat, dat$axis),
    function(d) all(diff(d$.arclen) >= 0),
    logical(1)
  ))
  expect_true(mon)
  # the chunk partition preserves total travelled distance exactly (summing
  # per-facet: each facet repeats the per-streamline totals)
  expect_equal(
    sum(dat$.dist),
    3 * sum(sqrt(rowSums(diff(pts)^2))),
    tolerance = 1e-6
  )

  # downsample cap: 5 points -> min(5, .n_chunks(200)) chunks of 1 point each;
  # with n_chunks = 5 the figure holds 5 chunks x 3 facets = 15 rows
  p5 <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl), n_chunks = 5L)
  dat5 <- .plot_data(p5)
  expect_equal(nrow(dat5), 15L)
  expect_equal(sort(unique(dat5$.chunk)), 1:5)
  # the caller's n_chunks is honoured when below the point count: 2 chunks
  p2 <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl), n_chunks = 2L)
  expect_equal(sort(unique(.plot_data(p2)$.chunk)), 1:2)

  # ---- colour modes ----------------------------------------------------------

  # orientation -> interval identity scale carrying the literal DTI hex colours
  expect_true(inherits(.plot_scales(p)[[1L]], "ScaleDiscreteIdentity"))

  # numeric metadata -> continuous gradient, legend named after the key
  pFA <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl), color = "FA")
  expect_true(inherits(.plot_scales(pFA)[[1L]], "ScaleContinuous"))
  expect_identical(.plot_scales(pFA)[[1L]]$name, "FA")
  expect_identical(
    deparse(.plot_layer(pFA)$mapping$colour),
    '~.data[["FA"]]'
  )

  # character metadata -> discrete brewer scale, legend named after the key
  slc <- fiber::streamline(pts, streamline_data = list(group = "tractA"))
  pc <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(slc), color = "group")
  expect_true(inherits(.plot_scales(pc)[[1L]], "ScaleDiscrete"))
  expect_identical(.plot_scales(pc)[[1L]]$name, "group")

  # fixed CSS/hex colour -> identity scale, and the drawn lines really are that
  # colour (regression: without the scale, steelblue ran through the default
  # discrete palette and rendered as hue #F8766D)
  pfx <- rtists:::.plot2d_impl(
    rtists:::.streamline_to_df(sl),
    color = "steelblue"
  )
  expect_true(inherits(.plot_scales(pfx)[[1L]], "ScaleDiscreteIdentity"))
  built <- ggplot2::ggplot_build(pfx)
  expect_true(all(unique(as.character(built$data[[1L]]$colour)) == "steelblue"))

  # linewidth / alpha overrides land on the layer
  pthick <- rtists:::.plot2d_impl(
    rtists:::.streamline_to_df(sl),
    linewidth = 1.5,
    alpha = 0.4
  )
  expect_equal(.plot_layer(pthick)$aes_params$linewidth, 1.5)
  expect_equal(.plot_layer(pthick)$aes_params$alpha, 0.4)

  # degenerate all-identical streamline: total arclength 0, chunk-by-point
  # fallback, figure still builds with all three facets
  deg <- fiber::streamline(cbind(
    X = c(1, 1, 1),
    Y = c(1, 1, 1),
    Z = c(1, 1, 1)
  ))
  pdeg <- rtists:::.plot2d_impl(rtists:::.streamline_to_df(deg))
  expect_inherits(pdeg, "ggplot")
  expect_equal(.plot_panels(pdeg), c("X", "Y", "Z"))
  expect_equal(.plot_data(pdeg)$.arclen, rep(0, nrow(.plot_data(pdeg))))

  # ... override reaches facet_wrap (free scales in both directions)
  pfree <- rtists:::.plot2d_impl(
    rtists:::.streamline_to_df(sl),
    scales = "free"
  )
  expect_true(.plot_facet(pfree)$params$free$x)
  expect_true(.plot_facet(pfree)$params$free$y)

  # ---- S7 dispatch -----------------------------------------------------------

  expect_inherits(plot2d(sl), "ggplot")
  expect_inherits(suppressMessages(plot2d(bun)), "ggplot")
  expect_inherits(suppressMessages(plot2d(bs)), "ggplot")

  # bundle_set: color_by_bundle groups each streamline under its parent name
  pbs <- suppressMessages(plot2d(bs, color_by_bundle = TRUE))
  expect_true(inherits(.plot_scales(pbs)[[1L]], "ScaleDiscrete"))
  expect_identical(.plot_scales(pbs)[[1L]]$name, "BundleName")
  expect_identical(unique(.plot_data(pbs)$.color), c("corpus", "callosum"))

  # cli progress alerts for bundle / bundle_set render
  msg_bun <- paste(
    capture.output(plot2d(bun), type = "message"),
    collapse = " "
  )
  expect_true(grepl("Rendering 2 streamlines", msg_bun))
  msg_bs <- paste(capture.output(plot2d(bs), type = "message"), collapse = " ")
  expect_true(grepl("Rendering 3 streamlines across 2 bundles", msg_bs))

  cat("plot2d tests OK\n")
}

# ---- ggplot2-missing branch (is_installed mocked) ----------------------------
# requireNamespace() returns TRUE once ggplot2 is loaded, and base namespaces
# are locked, so the guard lives behind the package-owned helper is_installed()
# (R/utils.R), mockable via mockthat in-process.
if (requireNamespace("mockthat", quietly = TRUE)) {
  msg <- mockthat::with_mock(
    `rtists::is_installed` = function(pkg) FALSE,
    tryCatch(
      {
        rtists:::.plot2d_impl(rtists:::.streamline_to_df(sl))
        "no-error"
      },
      error = function(e) conditionMessage(e)
    )
  )
  expect_true(grepl("plot2d\\(\\) requires the 'ggplot2' package", msg))
}

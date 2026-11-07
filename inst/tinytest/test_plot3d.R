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

# ---- .streamline_to_df ------------------------------------------------------

df <- rtists:::.streamline_to_df(sl)
expect_inherits(df, "data.frame")
expect_equal(nrow(df), 5L)
expect_true(all(c("StreamlineId", "PointId", "X", "Y", "Z") %in% names(df)))
expect_true(all(c("FA", "mean_FA") %in% names(df)))
expect_equal(df$StreamlineId, rep(1L, 5L))
expect_equal(df$PointId, 1:5)

df <- rtists:::.streamline_to_df(sl, streamline_id = 7L)
expect_equal(unique(df$StreamlineId), 7L)

# ---- .bundle_to_df ----------------------------------------------------------

df <- rtists:::.bundle_to_df(bun)
expect_inherits(df, "data.frame")
expect_equal(nrow(df), 10L)
expect_equal(sort(unique(df$StreamlineId)), 1:2)
expect_true("mean_FA" %in% names(df))

# ---- plot3d: return type -----------------------------------------------------

# three.js is the default backend
fig <- plot3d(sl)
expect_inherits(fig, "rtists")
fig <- plot3d(bun)
expect_inherits(fig, "rtists")

# plotly backend is selected explicitly. plotly is a Suggests-only
# dependency, so skip these assertions on platforms that do not carry it
# (e.g. some R-hub containers); the plotly-not-installed error branch itself
# is exercised by test_coverage.R via a mocked is_installed().
if (requireNamespace("plotly", quietly = TRUE)) {
  fig <- plot3d(sl, backend = "plotly")
  expect_inherits(fig, "plotly")
  fig <- plot3d(bun, backend = "plotly")
  expect_inherits(fig, "plotly")
}

# three.js tube mode (radius > 0) carries the tube payload
fig <- plot3d(sl, radius = 0.25)
expect_true(all(c("tubeOffsets", "radii") %in% names(fig$x)))

# ---- plot3d: colour modes ----------------------------------------------------

plot3d(sl)
plot3d(sl, color = "FA")
plot3d(bun, color = "mean_FA")
plot3d(sl, color = "steelblue")
plot3d(sl, color = "#E69F00")

# ---- three.js payload: mode / radii / linewidth branches ---------------------

# default -> line2: interleaved segments (6 floats/seg) + rgb (6/seg), no tube
fig <- plot3d(sl)
expect_equal(unclass(fig$x$mode), "line2")
# positions are 6 floats/segment packed as IEEE float32 -> 24 raw bytes/segment
expect_true(is.raw(fig$x$positions))
expect_equal(length(fig$x$positions), 24L * (nrow(pts) - 1L))
# colors are 6 uint8/segment (start rgb + end rgb, 0-255) -> raw bytes
expect_true(is.raw(fig$x$colors))
expect_equal(length(fig$x$colors), 6L * (nrow(pts) - 1L))
expect_true(is.null(fig$x$tubeOffsets))
expect_true(is.null(fig$x$radii))
expect_true(fig$x$linewidth > 0)

# scalar radius > 0 -> true 3D tube: per-point constant radii + tubeOffsets,
# no `thickness` echo
fig <- plot3d(sl, radius = 0.25)
expect_equal(unclass(fig$x$mode), "tube")
# radii are per-point floats packed as IEEE float32 -> 4 raw bytes/float
expect_true(is.raw(fig$x$positions))
expect_equal(length(fig$x$positions), 12L * nrow(pts))  # 3 floats x 4 bytes/point
expect_true(is.raw(fig$x$radii))
expect_equal(length(fig$x$radii), 4L * nrow(pts))
expect_true(!("thickness" %in% names(fig$x)))
expect_equal(fig$x$tubeOffsets, c(0L, nrow(pts)))
expect_true(is.null(fig$x$linewidth) || fig$x$linewidth > 0)

# scalar radius == 0 -> fast flat Line2 world width, radii dropped
fig <- plot3d(sl, radius = 0)
expect_equal(unclass(fig$x$mode), "line2")
expect_true(fig$x$linewidth > 0)
expect_true(is.null(fig$x$radii))

# per-streamline radius -> tube (variable per streamline)
fig <- plot3d(bun, radius = c(0.2, 0.8))
expect_equal(unclass(fig$x$mode), "tube")
expect_true(is.raw(fig$x$radii))
expect_length(fig$x$radii, 4L * nrow(pts) * 2L)
expect_equal(fig$x$tubeOffsets, c(0L, nrow(pts), 2L * nrow(pts)))

# per-point radius -> tube, radii equal to that vector
fig <- plot3d(sl, radius = c(0.1, 0.2, 0.3, 0.4, 0.5))
expect_equal(unclass(fig$x$mode), "tube")
expect_true(is.raw(fig$x$radii))
expect_equal(
  readBin(fig$x$radii, numeric(), size = 4L, n = 5L),
  c(0.1, 0.2, 0.3, 0.4, 0.5),
  tolerance = 1e-6
)

# invalid radius forms are rejected
expect_error(plot3d(sl, radius = c(0.1, 0.2)), "radius")

# ---- radius carried on the streamline objects (3js) -------------------------
# rtists relies on a `radius` key the generator stored in @point_data (per
# point) or @streamline_data (per streamline) whenever the caller does not pass
# an explicit `radius`. See the @radius doc on plot3d().

# per-streamline radius in @streamline_data -> one tube radius per fibre.
bun_r <- fiber::bundle(list(
  fiber::streamline(pts, streamline_data = list(radius = 0.2)),
  fiber::streamline(pts + 1, streamline_data = list(radius = 0.8))
))
fig <- plot3d(bun_r)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_equal(radii, rep(c(0.2, 0.8), each = nrow(pts)), tolerance = 1e-6)

# per-point radius in @point_data -> radius varying along the fibre.
sl_pp <- fiber::streamline(pts, point_data = list(radius = seq(0.1, 0.5, 0.1)))
fig <- plot3d(sl_pp)
expect_equal(unclass(fig$x$mode), "tube")
expect_equal(readBin(fig$x$radii, numeric(), size = 4L, n = nrow(pts)),
             seq(0.1, 0.5, 0.1), tolerance = 1e-6)

# an explicit `radius` argument overrides any radius stored on the object.
fig <- plot3d(bun_r, radius = 0.05)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_equal(unique(round(radii, 5)), 0.05)

# no radius anywhere and no argument -> fast thin Line2.
fig <- plot3d(sl)
expect_equal(unclass(fig$x$mode), "line2")
expect_true(is.null(fig$x$radii))

# rtists does NOT police overlap at render time: fat tubes on coincident
# streamlines keep the requested radius (overlap is the generator's concern;
# use prune() only when you fabricate tubes yourself from line-only data).
bs_same <- fiber::bundle_set(list(
  fiber::bundle(list(sl)),
  fiber::bundle(list(sl))
))
fig <- plot3d(bs_same, radius = 0.08)
expect_equal(unclass(fig$x$mode), "tube")
radii <- readBin(fig$x$radii, numeric(), size = 4L,
                 n = length(fig$x$radii) / 4L)
expect_true(all(abs(radii - 0.08) < 1e-5))   # requested radius left untouched

# ---- mixed-metadata bundle sets (CST/SLF/CC style) ---------------------------

# A bundle_set whose bundles carry different metadata columns must still fold
# into one dataframe: the CST bundle carries a `radius` key while the CC and
# SLF bundles carry none. `.bundle_set_to_df()` aligns the parts to the union
# of their columns (missing -> NA) instead of failing on an rbind mismatch.
sl_no_meta <- fiber::streamline(
  points = matrix(
    c(1, 0, 0, 2, 0, 0, 3, 0, 0), ncol = 3, byrow = TRUE,
    dimnames = list(NULL, c("X", "Y", "Z"))
  )
)
sl_radius <- fiber::streamline(
  points = matrix(
    c(0, 1, 0, 0, 2, 0), ncol = 3, byrow = TRUE,
    dimnames = list(NULL, c("X", "Y", "Z"))
  ),
  streamline_data = list(radius = 0.1)
)
bun_rad <- fiber::bundle(list(sl_radius, sl_radius))
bun_plain <- fiber::bundle(list(sl_no_meta))
bs_mixed <- fiber::bundle_set(list(CST = bun_rad, CC = bun_plain))

mdf <- rtists:::.bundle_set_to_df(bs_mixed)
expect_inherits(mdf, "data.frame")
expect_true("radius" %in% names(mdf))            # union carries the radius column
# only the CST streamlines actually hold a radius; the CC ones are NA
expect_equal(sort(unique(mdf$BundleName)), c("CC", "CST"))
expect_true(all(is.na(mdf$radius[mdf$BundleName == "CC"])))
expect_true(all(mdf$radius[mdf$BundleName == "CST"] == 0.1))

# plot3d on the mixed set draws a widget without erroring.
fig <- suppressMessages(plot3d(bs_mixed))
expect_inherits(fig, "rtists")
cat("mixed-metadata bundle_set tests OK\n")

# ---- three.js hover tooltip (tooltip= argument) -----------------------------
# The three.js backend ships a structured per-point tooltip payload
# (`tooltipData`): `bundle` (per-point bundle label, or NULL) and `xyz`
# (per-point formatted coordinates), both pinned and always shown, plus
# `columns` (the toggleable attribute columns), `shown` (their initial
# selection), and `values` (a named list mapping each column to its per-point
# formatted display string). `tooltip=TRUE` (default) selects every attribute
# column; `tooltip=FALSE` disables the payload; a character vector restricts
# the initial selection. Line2 mode also carries `segToPoint`.

# default -> tooltipData present, structured, covers every packed point
fig <- plot3d(sl)
expect_true("tooltipData" %in% names(fig$x))
tt <- fig$x$tooltipData
expect_true(all(c("bundle", "xyz", "columns", "shown", "values") %in% names(tt)))
expect_null(tt$bundle)                    # a single streamline has no name
expect_length(tt$xyz, nrow(pts))
expect_true(all(c("FA", "mean_FA") %in% tt$columns))
# default selects all toggleable columns
expect_true(setequal(tt$shown, tt$columns))
expect_true(all(c("FA", "mean_FA") %in% names(tt$values)))
expect_length(tt$values$FA, nrow(pts))
expect_length(tt$values$mean_FA, nrow(pts))
# formatted values match the prior string semantics
expect_true(grepl("X:", tt$xyz[1]))
expect_equal(tt$values$FA[1], "0.3")
expect_equal(tt$values$mean_FA[1], "0.5")
# line2 carries the segment -> point index map
expect_true("segToPoint" %in% names(fig$x))
expect_equal(fig$x$segToPoint, seq_len(nrow(pts) - 1L) - 1L)

# tube mode: no segToPoint needed; same structured payload
fig <- plot3d(sl, radius = 0.25)
expect_equal(unclass(fig$x$mode), "tube")
expect_true("tooltipData" %in% names(fig$x))
tt <- fig$x$tooltipData
expect_length(tt$xyz, nrow(pts))
expect_null(fig$x$segToPoint)             # tube mode maps hits by streamline offset

# tooltip = FALSE -> the payload is dropped entirely
fig <- plot3d(sl, tooltip = FALSE)
expect_false("tooltipData" %in% names(fig$x))
expect_false("segToPoint" %in% names(fig$x))

# tooltip = character vector -> all columns offered, only the request selected
fig <- plot3d(sl, tooltip = "FA")
expect_true("tooltipData" %in% names(fig$x))
tt <- fig$x$tooltipData
expect_true(all(c("FA", "mean_FA") %in% tt$columns))  # both still toggleable
expect_true(setequal(tt$shown, "FA"))
# unknown column names are ignored rather than erroring
fig <- plot3d(sl, tooltip = c("FA", "not_a_column"))
tt <- fig$x$tooltipData
expect_true(setequal(tt$shown, "FA"))

# bundle_set: the bundle name is pinned and per-point
b1 <- fiber::bundle(list(sl))
b2 <- fiber::bundle(list(fiber::streamline(pts + 1)))
bs_tt <- fiber::bundle_set(list(CST = b1, CC = b2))
fig <- suppressMessages(plot3d(bs_tt))
expect_true("tooltipData" %in% names(fig$x))
tt <- fig$x$tooltipData
expect_length(tt$bundle, length(tt$xyz))
expect_equal(tt$bundle[1], "CST")
expect_true("CC" %in% tt$bundle)
# the bundle name is pinned, not a toggleable column
expect_false("BundleName" %in% tt$columns)
# `shown` is a subset of `columns` for the default selection
expect_true(all(tt$shown %in% tt$columns))
cat("tooltip tests OK\n")

# ---- three.js legend (aesthetic-mapping panel) ------------------------------
# The three.js widget ships a `legendData` payload driving the legend panel:
# `n_pts` (per-streamline point counts, unnamed so jsonlite emits an array and
# the renderer can index per-streamline visibility), `bundlePerSl` + 
# `bundleNames` (per-streamline bundle category for bundle_set objects),
# `attrsPoint` (point-scoped attribute series, numeric packed as Float32 raw)
# and `attrsSl` (streamline-scoped representative values) for live remapping,
# and `ramp` (3x256 Uint8 colour ramp). No attribute column -> legendData is
# NULL. `BundleName` is offered as a per-bundle visual key, never as a point
# series.
#
# single streamline, line2 and tube modes both ship the payload
fig <- plot3d(sl)
expect_true("legendData" %in% names(fig$x))
ld <- fig$x$legendData
expect_equal(unclass(ld$n_pts), 5L)          # 5 points
expect_null(ld$bundlePerSl)                  # no BundleName on a plain streamline
expect_null(ld$bundleNames)
expect_true("FA" %in% names(ld$attrsPoint))  # point-scoped
expect_equal(ld$attrsSl$mean_FA, 0.5)        # streamline-scoped
expect_length(ld$attrsPoint$FA, 5L * 4L)     # numeric packed as Float32 raw
expect_false("mean_FA" %in% names(ld$attrsPoint))   # constant within streamline
expect_length(ld$ramp, 3L * 256L)            # 3x256 colour ramp

fig <- plot3d(sl, radius = 0.25)             # tube mode
expect_true("legendData" %in% names(fig$x))
expect_equal(unclass(fig$x$legendData$n_pts), 5L)

# bundle_set -> per-streamline bundle category, named and indexed
fig <- suppressMessages(plot3d(bs_tt))
ld <- fig$x$legendData
expect_equal(unclass(ld$n_pts), c(5L, 5L))
expect_equal(ld$bundleNames, c("CST", "CC"))
expect_equal(ld$bundlePerSl, c(1L, 2L))      # 1-based category index per streamline
expect_equal(ld$attrsSl$BundleName, c("CST", "CC"))
expect_false("BundleName" %in% names(ld$attrsPoint))   # bundle key is sl-scoped
# streamline-scoped attr absent on the second bundle pads to NA
expect_equal(ld$attrsSl$mean_FA, c(0.5, NA))
cat("legend tests OK\n")

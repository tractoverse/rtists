# ---- internal helpers --------------------------------------------------------

# Insert a row of NAs after each group so plotly renders disconnected line
# segments within a single scatter3d trace.
.add_na_separators <- function(df) {
  parts <- split(df, df$StreamlineId)
  do.call(rbind, lapply(parts, function(part) {
    na_row <- part[1L, , drop = FALSE]
    na_row[seq_along(na_row)] <- NA
    rbind(part, na_row)
  }))
}

# Compute per-point orientation colours for one streamline's data frame.
# Maps |dx|, |dy|, |dz| (normalised) to the R, G, B channels — the standard
# DTI colour convention (left–right = red, anterior–posterior = green,
# superior–inferior = blue).
.color_by_orientation <- function(df) {
  n  <- nrow(df)
  dx <- c(diff(df$X), NA_real_)
  dy <- c(diff(df$Y), NA_real_)
  dz <- c(diff(df$Z), NA_real_)
  # Last point: copy direction from the previous segment
  dx[n] <- dx[n - 1L]
  dy[n] <- dy[n - 1L]
  dz[n] <- dz[n - 1L]
  norm       <- sqrt(dx^2 + dy^2 + dz^2)
  norm[norm == 0 | is.na(norm)] <- 1
  grDevices::rgb(abs(dx) / norm, abs(dy) / norm, abs(dz) / norm)
}

# Build the colour column and the plotly `line` argument list, then call
# plot_ly on the prepared data frame.
# plotly backend is only loaded on demand (Suggests): give a clear error
# if it was not installed rather than failing deep inside plotly:: calls.
.plot3d_impl <- function(df, color, palette, linewidth, opacity, ...) {
  if (!is_installed("plotly")) {
    stop(
      "The plotly backend requires the 'plotly' package; install it with " ,
      "install.packages('plotly') or use the default backend = 'threejs'.",
      call. = FALSE
    )
  }
  meta_keys <- setdiff(names(df), c("StreamlineId", "PointId", "X", "Y", "Z"))

  # ---- resolve colour --------------------------------------------------------
  if (color == "orientation") {
    parts <- split(df, df$StreamlineId)
    parts <- lapply(parts, function(part) {
      part[[".color"]] <- .color_by_orientation(part)
      part
    })
    df        <- do.call(rbind, parts)
    line_args <- list(color = ~.color, width = linewidth)

  } else if (color %in% meta_keys) {
    df[[".color"]] <- df[[color]]
    if (is.numeric(df[[".color"]])) {
      line_args <- list(
        color    = ~.color,
        colorscale = palette,
        colorbar = list(title = color),
        width    = linewidth
      )
    } else {
      # Character / factor: plotly will pick its own discrete colours
      line_args <- list(color = ~.color, width = linewidth)
    }

  } else {
    # Treat as a fixed CSS / hex colour string
    line_args <- list(color = color, width = linewidth)
  }

  # ---- NA separators so all streamlines share one trace ----------------------
  df <- .add_na_separators(df)

  # ---- fix NA colour values introduced by the separator rows -----------------
  # plotly scatter3d silently drops the whole trace when the line$color array
  # contains NA.  Replace NA placeholders with a transparent/neutral value that
  # has no visual effect (the x/y/z NAs already break the line segment).
  if (".color" %in% names(df)) {
    if (is.character(df[[".color"]])) {
      df[[".color"]][is.na(df[[".color"]])] <- "rgba(0,0,0,0)"
    } else {
      df[[".color"]][is.na(df[[".color"]])] <- 0
    }
  }

  # ---- hover text from available metadata ------------------------------------
  visible_keys <- intersect(meta_keys, names(df))
  if (length(visible_keys) > 0L) {
    hover_parts    <- lapply(visible_keys, \(k) paste0(k, ": ", df[[k]]))
    df[[".hover"]] <- Reduce(\(a, b) paste(a, b, sep = "<br>"), hover_parts)
    hover_arg      <- ~.hover
    hoverinfo      <- "text"
  } else {
    hover_arg  <- NULL
    hoverinfo  <- "none"
  }

  # ---- build plotly figure ---------------------------------------------------
  fig <- plotly::plot_ly(
    data      = df,
    x         = ~X,
    y         = ~Y,
    z         = ~Z,
    type      = "scatter3d",
    mode      = "lines",
    opacity   = opacity,
    line      = line_args,
    text      = hover_arg,
    hoverinfo = hoverinfo
  )

  plotly::layout(
    fig,
    scene = list(
      xaxis      = list(title = "X (mm)"),
      yaxis      = list(title = "Y (mm)"),
      zaxis      = list(title = "Z (mm)"),
      aspectmode = "data"
    ),
    ...
  )
}

# ---- S7 generic --------------------------------------------------------------

#' Interactive 3D line plot for tractography streamlines and bundles
#'
#' @description
#' `plot3d()` is an S7 generic that produces an interactive 3D plot of
#' tractography objects from the [fiber](https://tractoverse.github.io/fiber/)
#' package. Two htmlwidget backends are available:
#'
#' - `"threejs"` (default): a self-contained three.js renderer with real
#'   world-space line thickness (true 3D tubes), depth-sorted
#'   transparency, and a fast single-mesh line mode that scales to large
#'   bundles.
#' - `"plotly"`: a `scatter3d` line plot where all streamlines share one trace
#'   separated by `NA` break-points. A deliberately opt-in alternative renderer
#'   for when you prefer an interactive plotly surface.
#'
#' Methods are available for the following classes:
#'
#' `r doclisting::methods_list("plot3d")`
#'
#' @param x A [fiber::streamline], [fiber::bundle], or [fiber::bundle_set] object.
#' @param color Controls how streamline colours are assigned. Accepted values:
#'
#'   - `"orientation"` (default): per-point RGB colour derived from the local
#'     fibre direction. The absolute values of the normalised tangent vector
#'     \eqn{(|dx|, |dy|, |dz|)} are mapped to the R, G, B channels — the
#'     standard DTI colour convention (left-right = red, anterior-posterior =
#'     green, superior-inferior = blue).
#'   - A **metadata key**: a string matching a key in `@point_data`
#'     (per-point scalar) or `@streamline_data` (per-streamline scalar,
#'     broadcast to all points). Numeric values are mapped to a continuous
#'     colour scale (`palette`); character values are coloured categorically.
#'   - A **CSS/hex colour string**: e.g. `"#E69F00"` or `"steelblue"`. All
#'     lines are drawn in that fixed colour.
#'
#' @param palette A [plotly] / ColorBrewer colour scale name applied when
#'   `color` is a numeric metadata key. Defaults to `"Viridis"`.
#' @param backend Character. Which htmlwidget renderer to use: `"threejs"`
#'   (default) or `"plotly"`. The three.js backend supports real world-space
#'   line thickness (true 3D tubes) and object-level depth-sorted
#'   transparency; the plotly backend is an opt-in alternative for interactive
#'   plotly-style charts.
#' @param linewidth Numeric. Width of the plotted lines. Defaults to `2`. On the
#'   three.js backend this maps to `THREE.LineBasicMaterial.linewidth`, which
#'   WebGL caps at `1` on most platforms; use `radius` for genuinely thick
#'   fibres.
#' @param radius Numeric radius in world units (three.js backend only). This is
#'   the knob for **true 3D tubes**; there is no separate `thickness` argument.
#'   Accepts:
#'
#'   - `NULL` (default): thin lines (fast `Line2` at `linewidth`).
#'   - A scalar `0`: fast flat `Line2` at `linewidth` (nothing needs a tube).
#'   - A positive **scalar**: every streamline is drawn as a real 3D
#'     `TubeGeometry` tube of this constant world radius, with genuine thickness,
#'     Phong flat shading, and object-level depth-sorted transparency (each tube
#'     is its own mesh sorted back-to-front).
#'   - A **per-streamline vector** (length == number of streamlines): one
#'     constant radius per line, drawn as `TubeGeometry`.
#'   - A **per-point vector** (length == total number of points): radius varying
#'     along each streamline, drawn as `TubeGeometry` with radial displacement —
#'     the most general form.
#' @param bg Background colour (CSS) of the scene (three.js backend only).
#'   Defaults to `"#111111"`.
#' @param opacity Numeric in \[0, 1\]. Global line opacity. Defaults to `0.5`.
#' @param ... Additional named arguments. Only the plotly backend uses these,
#'   forwarding them to [plotly::layout()] (e.g. `title = "My bundle"`); the
#'   three.js backend (default) ignores them.
#'
#' @returns An interactive htmlwidget.
#' @seealso [fiber::streamline], [fiber::bundle], [fiber::bundle_set]
#' @export
#'
#' @examples
#' library(fiber)
#'
#' # --- a realistic streamline -----------------------------------------------
#' # A dense, smoothly meandering 3-D curve advanced in small steps along X,
#' # thin and elongated like a real DTI tract (spaghetti), not a coarse fat
#' # polyline.
#' n  <- 200L
#' t  <- seq(0, 4 * pi, length.out = n)
#' pts <- cbind(
#'   X = seq_len(n) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
#'   streamline_data = list(mean_FA = 0.5)
#' )
#'
#' # Default: colour by local fibre orientation
#' plot3d(sl)
#'
#' # Colour by per-point FA (continuous colour scale)
#' plot3d(sl, color = "FA")
#'
#' # Fixed colour
#' plot3d(sl, color = "steelblue", opacity = 0.8)
#'
#' # --- bundle example -------------------------------------------------------
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   # Each strand meanders gently (amplitude 0.25) but is spaced 1.2 units
#'   # apart in Y, well beyond its meander, so filled tubes (plus their black
#'   # outline) stay clear of one another at a visible radius.
#'   pts <- cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   )
#'   streamline(
#'     pts,
#'     point_data      = list(FA = 0.4 + 0.3 * sin((t + 1.3 * i) / 2)),
#'     streamline_data = list(mean_FA = 0.5)
#'   )
#' }
#' bun <- bundle(lapply(seq_len(6), strand))
#'
#' # Thin lines coloured by local fibre orientation (default)
#' plot3d(bun)
#'
#' # Colour by a per-streamline scalar key on a continuous palette
#' plot3d(bun, color = "mean_FA", palette = "RdYlBu")
#'
#' # True 3D tubes via a constant world radius, then a per-streamline radius:
#' # a vector with one entry per streamline gives each a different tube radius.
#' plot3d(bun, radius = 0.08)
#' plot3d(bun, radius = c(0.02, 0.06, 0.10, 0.02, 0.06, 0.10))
#'
#' # Fade the whole bundle with transparency
#' plot3d(bun, opacity = 0.3)
#'
#' # Prune to a spread-out subset whose fat tubes do not overlap. Pruning
#' # uses the tube radius; here 6 strands packed 1.2 units apart overlap at
#' # radius 1, so prune keeps just the 2 that stay clear of one another.
#' pruned <- prune(bun, radius = 1)
#' length(pruned@streamlines)
#'
#' # Plot the pruned set at the same fat radius so the non-overlap is visible.
#' plot3d(pruned, radius = 1)
#'
#' # --- bundle set example -------------------------------------------------
#' # A second bundle that crosses the first: its strands meander up and down
#' # with a growing Y amplitude, sweeping through the first bundle's parallel
#' # set so the two fibre populations interleave.
#' strand2 <- function(i) {
#'   t   <- seq(0, 4 * pi, length.out = 200)
#'   amp <- 1.0 + 0.35 * i
#'   pts <- cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = amp * sin(t + 1.3 * i),
#'     Z = 0.25 * cos(t + 0.7 * i) + (i - 3.5) * 0.15
#'   )
#'   streamline(
#'     pts,
#'     point_data      = list(FA = 0.4 + 0.3 * sin((t + 1.3 * i) / 2)),
#'     streamline_data = list(mean_FA = 0.5)
#'   )
#' }
#' bun_cross  <- bundle(lapply(seq_len(6), strand2))
#' bun_set <- bundle_set(list(bun, bun_cross))
#'
#' # Colour the two crossing bundles distinctly, or draw them as fat
#' # transparent tubes on top of other geometry.
#' plot3d(bun_set, color_by_bundle = TRUE)
#' plot3d(bun_set, radius = 0.08, opacity = 0.4)
plot3d <- S7::new_generic(
  name = "plot3d",
  dispatch_args = "x",
  fun = function(x, color = "orientation", palette = "Viridis",
                 backend = c("threejs", "plotly"), linewidth = 2,
                 radius = NULL, opacity = 0.5,
                 bg = "#111111", ...) {
    S7::S7_dispatch()
  }
)

# ---- S7 methods --------------------------------------------------------------

#' [plot3d()] method for `fiber::streamline` objects
#'
#' Renders a single [fiber::streamline] as an interactive 3D line plot. See
#' [plot3d()] for the full parameter documentation and examples.
#'
#' @param x A [fiber::streamline] object.
#' @inheritParams plot3d
#' @returns An interactive htmlwidget (three.js or plotly, see [`plot3d()`]).
#' @seealso [plot3d()]
#' @name plot3d-fiber-streamline-method
#' @aliases plot3d,fiber::streamline-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # --- a realistic streamline -----------------------------------------------
#' # A dense, smoothly meandering 3-D curve advanced in small steps along X,
#' # thin and elongated like a real DTI tract (spaghetti), not a coarse fat
#' # polyline.
#' n  <- 200L
#' t  <- seq(0, 4 * pi, length.out = n)
#' pts <- cbind(
#'   X = seq_len(n) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
#'   streamline_data = list(mean_FA = 0.5)
#' )
#'
#' # Default: colour by local fibre orientation
#' plot3d(sl)
#'
#' # Colour by per-point FA (continuous colour scale)
#' plot3d(sl, color = "FA")
#'
#' # Fixed colour
#' plot3d(sl, color = "steelblue", opacity = 0.8)
S7::method(plot3d, fiber::streamline) <- function(
    x,
    color     = "orientation",
    palette   = "Viridis",
    backend   = c("threejs", "plotly"),
    linewidth = 2,
    radius    = NULL,
    opacity   = 0.5,
    bg        = "#111111",
    ...) {
  backend <- match.arg(backend)
  df <- .streamline_to_df(x, streamline_id = 1L)
  if (backend == "threejs") {
    .plot3d_threejs(
      df        = df,
      color     = color,
      palette   = palette,
      linewidth = linewidth,
      radius    = radius,
      opacity   = opacity,
      bg        = bg,
      ...
    )
  } else {
    .plot3d_impl(
      df        = df,
      color     = color,
      palette   = palette,
      linewidth = linewidth,
      opacity   = opacity,
      ...
    )
  }
}

#' [plot3d()] method for `fiber::bundle` objects
#'
#' Renders all streamlines in a [fiber::bundle] as a single interactive 3D
#' line plot. See [plot3d()] for the full parameter documentation and examples.
#'
#' @param x A [fiber::bundle] object.
#' @inheritParams plot3d
#' @returns An interactive htmlwidget (three.js or plotly, see [`plot3d()`]).
#' @seealso [plot3d()]
#' @name plot3d-fiber-bundle-method
#' @aliases plot3d,fiber::bundle-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # A bundle of six gently meandering strands, each carrying per-point FA and
#' # a per-streamline `region` label (used below for categorical colouring).
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   pts <- cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   )
#'   streamline(
#'     pts,
#'     point_data      = list(FA = 0.4 + 0.3 * sin((t + 1.3 * i) / 2)),
#'     streamline_data = list(mean_FA = 0.5,
#'                            region  = if (i %% 2) "left" else "right")
#'   )
#' }
#' bun <- bundle(lapply(seq_len(6), strand))
#'
#' # Default: thin lines coloured by local fibre orientation
#' plot3d(bun)
#'
#' # Colour by a per-streamline scalar key on a continuous palette
#' plot3d(bun, color = "mean_FA", palette = "RdYlBu")
#'
#' # Colour by a per-streamline character key (categorical)
#' plot3d(bun, color = "region")
#'
#' # A constant world radius: every strand becomes a true 3D tube with a black
#' # outline (Phong flat shaded), the densest, most brain-like rendering.
#' plot3d(bun, radius = 0.08)
#'
#' # Per-streamline variable radius: one tube radius per line (TubeGeometry).
#' # A length-n vector picks a different radius for each of the 6 strands.
#' plot3d(bun, radius = c(0.02, 0.06, 0.10, 0.02, 0.06, 0.10))
#'
#' # Per-point variable radius: a vector as long as the total point count gives
#' # a radius that varies along each strand (the most general form).
#' n_pts <- sum(vapply(bun@streamlines, function(s) nrow(s@points), integer(1)))
#' plot3d(bun, radius = rep(c(0.04, 0.10), length.out = n_pts))
#'
#' # Transparency: fade the bundle to overlay it on other geometry
#' plot3d(bun, opacity = 0.3)
#'
#' # Prune to a spread-out subset whose fat tubes do not overlap. The 6 strands
#' # packed 1.2 units apart overlap at radius 1, so prune keeps the 2 strands
#' # that stay clear of one another.
#' pruned <- prune(bun, radius = 1)
#' length(pruned@streamlines)
#'
#' # Plot the pruned bundle at the same fat radius as the prune test.
#' plot3d(pruned, radius = 1)
S7::method(plot3d, fiber::bundle) <- function(
    x,
    color     = "orientation",
    palette   = "Viridis",
    backend   = c("threejs", "plotly"),
    linewidth = 2,
    radius    = NULL,
    opacity   = 0.5,
    bg        = "#111111",
    ...) {
  backend <- match.arg(backend)
  n <- length(x@streamlines)
  cli::cli_alert_info("Rendering {n} streamline{?s}...")
  df <- .bundle_to_df(x)
  if (backend == "threejs") {
    .plot3d_threejs(
      df        = df,
      color     = color,
      palette   = palette,
      linewidth = linewidth,
      radius    = radius,
      opacity   = opacity,
      bg        = bg,
      ...
    )
  } else {
    .plot3d_impl(
      df        = df,
      color     = color,
      palette   = palette,
      linewidth = linewidth,
      opacity   = opacity,
      ...
    )
  }
}

#' [plot3d()] method for `fiber::bundle_set` objects
#'
#' Renders all bundles in a [fiber::bundle_set] as a single interactive 3D
#' line plot. Each bundle in the set (typically one per subject or session) can
#' be coloured uniformly by its bundle name or with the same per-streamline
#' colouring as [plot3d()] for [fiber::bundle] objects.
#' See [plot3d()] for the full parameter documentation.
#'
#' @param x A [fiber::bundle_set] object.
#' @inheritParams plot3d
#' @param color_by_bundle Logical. When `TRUE`, every streamline is coloured
#'   by its parent bundle name (one distinct colour per entry in the set),
#'   overriding the `color` argument. When `FALSE` (default), `color` is
#'   applied as-is, inheriting the same per-streamline colouring behaviour as
#'   the [fiber::bundle] method.
#' @returns An interactive htmlwidget (three.js or plotly, see [`plot3d()`]).
#' @seealso [plot3d()]
#' @name plot3d-fiber-bundle_set-method
#' @aliases plot3d,fiber::bundle_set-method
#' @usage NULL
#' @examples
#' library(fiber)
#'
#' # --- a realistic streamline -----------------------------------------------
#' # A dense, smoothly meandering 3-D curve advanced in small steps along X,
#' # thin and elongated like a real DTI tract (spaghetti), not a coarse fat
#' # polyline.
#' n  <- 200L
#' t  <- seq(0, 4 * pi, length.out = n)
#' pts <- cbind(
#'   X = seq_len(n) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
#'   streamline_data = list(mean_FA = 0.5)
#' )
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   # Each strand meanders gently (amplitude 0.25) but is spaced 1.2 units
#'   # apart in Y, well beyond its meander, so the filled tubes (plus their
#'   # black outline) stay clear of one another at a visible radius.
#'   pts <- cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   )
#'   streamline(
#'     pts,
#'     point_data      = list(FA = 0.4 + 0.3 * sin((t + 1.3 * i) / 2)),
#'     streamline_data = list(mean_FA = 0.5)
#'   )
#' }
#' # A first bundle of six parallel strands.
#' bun <- bundle(lapply(seq_len(6), strand))
#'
#' # A second bundle that crosses the first: its strands meander up and down
#' # (large Y amplitude) so they sweep through the first bundle's parallel set,
#' # interleaving the region instead of staying in a separate lane.
#' strand2 <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   # Amplitudes grow with the strand index so each crosses the full height of
#'   # the first bundle, giving clearly interleaved, crossing streamlines.
#'   amp <- 1.0 + 0.35 * i
#'   pts <- cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = amp * sin(t + 1.3 * i),
#'     Z = 0.25 * cos(t + 0.7 * i) + (i - 3.5) * 0.15
#'   )
#'   streamline(
#'     pts,
#'     point_data      = list(FA = 0.4 + 0.3 * sin((t + 1.3 * i) / 2)),
#'     streamline_data = list(mean_FA = 0.5)
#'   )
#' }
#' bun_cross <- bundle(lapply(seq_len(6), strand2))
#'
#' # A bundle set of the two crossing bundles.
#' bun_set <- bundle_set(list(bun, bun_cross))
#'
#' # Default: each streamline coloured by its local fibre orientation.
#' plot3d(bun_set)
#'
#' # Colour the two whole bundles distinctly (`color_by_bundle = TRUE`), so the
#' # crossing sets stand out against one another.
#' plot3d(bun_set, color_by_bundle = TRUE)
#'
#' # Fat tubes with object-level transparency, overlaid on other geometry.
#' plot3d(bun_set, radius = 0.08, opacity = 0.4)
#'
#' # Prune each bundle to a spread-out subset of non-overlapping tubes, then
#' # plot the pruned set at the same fat radius as the prune test.
#' pruned_set <- prune(bun_set, radius = 1)
#' length(pruned_set@bundles)
#' plot3d(pruned_set, radius = 1)
S7::method(plot3d, fiber::bundle_set) <- function(
    x,
    color           = "orientation",
    palette         = "Viridis",
    backend         = c("threejs", "plotly"),
    linewidth       = 2,
    radius          = NULL,
    opacity         = 0.5,
    bg              = "#111111",
    color_by_bundle = FALSE,
    ...) {
  backend <- match.arg(backend)
  n_bundles <- x@n_bundles
  n_sl      <- sum(vapply(x@bundles, \(b) b@n_streamlines, integer(1L)))
  cli::cli_alert_info(
    "Rendering {n_sl} streamline{?s} across {n_bundles} bundle{?s}..."
  )
  df <- .bundle_set_to_df(x)
  if (backend == "threejs") {
    .plot3d_threejs(
      df              = df,
      color           = if (color_by_bundle) "BundleName" else color,
      palette         = palette,
      linewidth       = linewidth,
      radius          = radius,
      opacity         = opacity,
      bg              = bg,
      color_by_bundle = color_by_bundle,
      ...
    )
  } else {
    .plot3d_impl(
      df        = df,
      color     = if (color_by_bundle) "BundleName" else color,
      palette   = palette,
      linewidth = linewidth,
      opacity   = opacity,
      ...
    )
  }
}

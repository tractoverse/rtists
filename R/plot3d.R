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
#'   radius is treated as data carried on the object: when `radius` is `NULL`
#'   (the default), a `radius` key in the streamlines' `@point_data` (per-point)
#'   or `@streamline_data` (per-streamline) is picked up and rendered as real
#'   3D tubes; tubes are drawn exactly at that radius, never shrunk to avoid
#'   overlap between neighbouring fibres (overlap is the generator's business,
#'   not rtists's). An explicit `radius` argument overrides any data. Accepts:
#'
#'   - `NULL` (default): draw at the object's own radius data if present,
#'     otherwise thin lines (fast `Line2` at `linewidth`).
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
#' @param tooltip Hover tooltip on the three.js backend. When a point of a
#'   streamline is hovered, an in-scene tooltip shows that bundle's name, the
#'   point's 3D coordinates, and the values of its attributes. Accepted values:
#'
#'   - `TRUE` (default): show the bundle name (when the object carries one), the
#'     coordinates, and **all** attributes recorded on the object (per-point,
#'     per-streamline, per-bundle and per-bundle-set alike).
#'   - `FALSE`: disable the tooltip entirely.
#'   - A character vector of attribute column names: show only those, alongside
#'     the always-included coordinates (and bundle name when present). Names that
#'     do not exist on the object are ignored.
#'
#'   Right-clicking the hovered tooltip opens a checkbox list of every toggleable
#'   column; ticking or unticking one updates the visible box immediately. The
#'   bundle name and coordinates stay pinned and cannot be toggled off.
#'
#'   The plotly backend ignores this argument (the plotly surface carries its
#'   own hover).
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
#' # --- a single realistic streamline ---------------------------------------
#' # A smooth fibre curving through 3-D space, sampled densely into small
#' # steps, thin like a real DTI tract rather than a coarse polyline.
#' t   <- seq(0, 4 * pi, length.out = 200)
#' pts <- cbind(
#'   X = seq_len(200) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
#'   streamline_data = list(mean_FA = 0.5)
#' )
#'
#' # Colour by local fibre orientation (default), by per-point FA, or by a
#' # fixed hue.
#' plot3d(sl)
#' plot3d(sl, color = "FA")
#' plot3d(sl, color = "steelblue", opacity = 0.8)
#'
#' # --- a small bundle carrying its own radius ------------------------------
#' # Eight streamlines of a pyramidal tract (corticospinal, CST) fanning
#' # upward toward the cortex. Each one carries a per-streamline `radius` in
#' # its data, so plot3d draws real 3D tubes straight from the object, with
#' # no radius argument needed.
#' cst_sl <- function(i) {
#'   t   <- seq(-1, 1, length.out = 120)      # -1 deep, +1 cortex
#'   fan <- (t + 1) / 2                        # 0 at depth, 1 at cortex
#'   streamline(
#'     cbind(
#'       X = 0.5 * sin(0.7 * t) + (i - 3.5) * 0.22 * (0.30 + 0.85 * fan),
#'       Y = 0.4 * cos(0.5 * t) + (i - 3.5) * 0.10 * (0.30 + 0.85 * fan),
#'       Z = 4 * t
#'     ),
#'     streamline_data = list(radius = 0.05 + 0.05 * (i / 8))
#'   )
#' }
#' cst <- bundle(lapply(seq_len(8), cst_sl))
#'
#' # Tubes at the radii carried in the data, or overridden by one explicit radius.
#' plot3d(cst)
#' plot3d(cst, radius = 0.08)
#'
#' # --- a 3-bundle crossing at the centrum semiovale -------------------------
#' # The pyramidal (CST, vertical), the superior longitudinal fasciculus
#' # (SLF, anterior-posterior) and the corpus callosum (CC, left-right) all
#' # run through the centrum semiovale. Drawn at the origin they cross there,
#' # giving the classic DTI orientation colours: CST blue (superior-inferior),
#' # SLF green (anterior-posterior), CC red (left-right).
#' cc_sl <- function(i) {
#'   t <- seq(-1, 1, length.out = 120)
#'   streamline(cbind(
#'     X = 6 * t,
#'     Y = 0.35 * t * t + (i - 3.5) * 0.18 * (1 + 0.4 * abs(t)),
#'     Z = 0.3 * sin(pi * t) + (i - 3.5) * 0.12
#'   ))
#' }
#' slf_sl <- function(i) {
#'   t <- seq(-1, 1, length.out = 120)
#'   streamline(cbind(
#'     X = 0.35 * sin(pi * t) + (i - 3.5) * 0.15,
#'     Y = 6 * t,
#'     Z = 0.5 * sin(0.8 * t) + (i - 3.5) * 0.14
#'   ))
#' }
#' cc  <- bundle(lapply(seq_len(8), cc_sl))
#' slf <- bundle(lapply(seq_len(8), slf_sl))
#' cs  <- bundle_set(list(CST = cst, CC = cc, SLF = slf))
#'
#' plot3d(cs, radius = 0.05)
#' plot3d(cs, color_by_bundle = TRUE, radius = 0.05)

plot3d <- S7::new_generic(
  name = "plot3d",
  dispatch_args = "x",
  fun = function(x, color = "orientation", palette = "Viridis",
                 backend = c("threejs", "plotly"), linewidth = 2,
                 radius = NULL, opacity = 0.5,
                 bg = "#111111", tooltip = TRUE, ...) {
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
#' # A single fibre curving through 3-D space, sampled densely into small
#' # steps, thin like a real DTI tract rather than a coarse polyline.
#' t   <- seq(0, 4 * pi, length.out = 200)
#' pts <- cbind(
#'   X = seq_len(200) * 0.1,
#'   Y = 0.5 * sin(t),
#'   Z = 0.5 * cos(t)
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = 0.4 + 0.3 * sin(t / 2)),
#'   streamline_data = list(mean_FA = 0.5)
#' )
#'
#' # Colour by local fibre orientation (default), by per-point FA, or by a
#' # fixed hue.
#' plot3d(sl)
#' plot3d(sl, color = "FA")
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
    tooltip   = TRUE,
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
      tooltip   = tooltip,
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
#' # A small pyramidal tract (corticospinal, CST): eight streamlines fanning
#' # upward from deep white matter toward the cortex, each carrying its own
#' # per-streamline `radius`, `mean_FA` and hemisphere `region`.
#' cst_sl <- function(i) {
#'   t   <- seq(-1, 1, length.out = 120)      # -1 deep, +1 cortex
#'   fan <- (t + 1) / 2                        # 0 at depth, 1 at cortex
#'   streamline(
#'     cbind(
#'       X = 0.5 * sin(0.7 * t) + (i - 3.5) * 0.22 * (0.30 + 0.85 * fan),
#'       Y = 0.4 * cos(0.5 * t) + (i - 3.5) * 0.10 * (0.30 + 0.85 * fan),
#'       Z = 4 * t
#'     ),
#'     streamline_data = list(
#'       radius = 0.05 + 0.05 * (i / 8),
#'       mean_FA = 0.4 + 0.08 * i,
#'       region  = if (i %% 2) "left" else "right"
#'     )
#'   )
#' }
#' cst <- bundle(lapply(seq_len(8), cst_sl))
#'
#' # Tubes at the radii carried in the data, or overridden by one explicit radius.
#' plot3d(cst)
#' plot3d(cst, radius = 0.08)
#'
#' # Colour by a per-streamline scalar key (continuous palette) or by a
#' # per-streamline character key (categorical).
#' plot3d(cst, color = "mean_FA", palette = "RdYlBu")
#' plot3d(cst, color = "region")
#'
#' # Transparency: fade the bundle to overlay it on other geometry.
#' plot3d(cst, opacity = 0.3)
#'
#' # Line-only streamlines (no radius data) draw as thin lines. If you decide
#' # to fatten them into tubes yourself, prune() keeps a spread-out subset
#' # whose tubes do not overlap, so the overlap is not introduced by you.
#' strand <- function(i) {
#'   t <- seq(0, 4 * pi, length.out = 200)
#'   streamline(cbind(
#'     X = seq_len(200) * 0.1,
#'     Y = 0.25 * sin(t + 1.3 * i) + (i - 3.5) * 1.2,
#'     Z = 0.25 * cos(t) + (i - 3.5) * 0.15
#'   ))
#' }
#' lines <- bundle(lapply(seq_len(6), strand))
#' plot3d(lines)
#' pruned <- prune(lines, radius = 1)
#' length(pruned@streamlines)
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
    tooltip   = TRUE,
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
      tooltip   = tooltip,
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
#' # Three white-matter tracts that all run through the centrum semiovale:
#' # the pyramidal/corticospinal tract (CST, vertical/fanning), the superior
#' # longitudinal fasciculus (SLF, anterior-posterior) and the corpus callosum
#' # (CC, left-right). Drawn to pass through the origin they cross there,
#' # producing the classic DTI orientation colours: CST blue (superior-
#' # inferior), SLF green (anterior-posterior), CC red (left-right).
#' cst_sl <- function(i) {
#'   t   <- seq(-1, 1, length.out = 120)      # -1 deep, +1 cortex
#'   fan <- (t + 1) / 2
#'   streamline(cbind(
#'     X = 0.5 * sin(0.7 * t) + (i - 3.5) * 0.22 * (0.30 + 0.85 * fan),
#'     Y = 0.4 * cos(0.5 * t) + (i - 3.5) * 0.10 * (0.30 + 0.85 * fan),
#'     Z = 4 * t
#'   ))
#' }
#' cc_sl <- function(i) {
#'   t <- seq(-1, 1, length.out = 120)
#'   streamline(cbind(
#'     X = 6 * t,
#'     Y = 0.35 * t * t + (i - 3.5) * 0.18 * (1 + 0.4 * abs(t)),
#'     Z = 0.3 * sin(pi * t) + (i - 3.5) * 0.12
#'   ))
#' }
#' slf_sl <- function(i) {
#'   t <- seq(-1, 1, length.out = 120)
#'   streamline(cbind(
#'     X = 0.35 * sin(pi * t) + (i - 3.5) * 0.15,
#'     Y = 6 * t,
#'     Z = 0.5 * sin(0.8 * t) + (i - 3.5) * 0.14
#'   ))
#' }
#' cst <- bundle(lapply(seq_len(8), cst_sl))
#' cc  <- bundle(lapply(seq_len(8), cc_sl))
#' slf <- bundle(lapply(seq_len(8), slf_sl))
#' cs  <- bundle_set(list(CST = cst, CC = cc, SLF = slf))
#'
#' # Orientation-coloured crossing bundles (the triple-colour crossing).
#' plot3d(cs)
#'
#' # Colour each whole bundle distinctly to separate the three tracts.
#' plot3d(cs, color_by_bundle = TRUE)
#'
#' # Fat transparent tubes overlaid on other geometry.
#' plot3d(cs, radius = 0.08, opacity = 0.4)

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
    tooltip         = TRUE,
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
      tooltip         = tooltip,
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

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
.plot3d_impl <- function(df, color, palette, linewidth, opacity, ...) {
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
#' `plot3d()` is an S7 generic that produces an interactive 3D line plot of
#' tractography objects from the [fiber](https://tractoverse.github.io/fiber/)
#' package using [plotly][plotly::plotly].
#' Methods are available for the following classes:
#'
#' `r doclisting::methods_list("plot3d")`
#'
#' All streamlines are rendered as a single `scatter3d` trace separated by
#' `NA` break-points, which keeps the widget lightweight even for large
#' bundles.
#'
#' @param x A [fiber::streamline] or [fiber::bundle] object.
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
#' @param linewidth Numeric. Width of the plotted lines. Defaults to `2`.
#' @param opacity Numeric in \[0, 1\]. Global line opacity. Defaults to `0.5`.
#' @param ... Additional named arguments forwarded to [plotly::layout()],
#'   e.g. `title = "My bundle"`.
#'
#' @returns An interactive [plotly] htmlwidget.
#' @seealso [fiber::streamline], [fiber::bundle]
#' @export
#'
#' @examples
#' \dontrun{
#' library(fiber)
#'
#' # --- minimal streamline example -------------------------------------------
#' pts <- matrix(
#'   c(0, 0, 0,
#'     1, 1, 0,
#'     2, 1, 1,
#'     3, 2, 1),
#'   ncol = 3, byrow = TRUE,
#'   dimnames = list(NULL, c("X", "Y", "Z"))
#' )
#' sl <- streamline(
#'   points          = pts,
#'   point_data      = list(FA = c(0.3, 0.5, 0.7, 0.6)),
#'   streamline_data = list(mean_FA = 0.525)
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
#' bun <- bundle(list(sl, sl))
#' plot3d(bun)
#' plot3d(bun, color = "mean_FA", palette = "RdYlBu")
#' }
plot3d <- S7::new_generic(
  name = "plot3d",
  dispatch_args = "x",
  fun = function(x, color = "orientation", palette = "Viridis",
                 linewidth = 2, opacity = 0.5, ...) {
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
#' @returns An interactive [plotly] htmlwidget.
#' @seealso [plot3d()]
#' @name plot3d-fiber-streamline-method
#' @aliases plot3d,fiber::streamline-method
#' @usage NULL
S7::method(plot3d, fiber::streamline) <- function(
    x,
    color     = "orientation",
    palette   = "Viridis",
    linewidth = 2,
    opacity   = 0.5,
    ...) {
  df <- .streamline_to_df(x, streamline_id = 1L)
  .plot3d_impl(
    df        = df,
    color     = color,
    palette   = palette,
    linewidth = linewidth,
    opacity   = opacity,
    ...
  )
}

#' [plot3d()] method for `fiber::bundle` objects
#'
#' Renders all streamlines in a [fiber::bundle] as a single interactive 3D
#' line plot. See [plot3d()] for the full parameter documentation and examples.
#'
#' @param x A [fiber::bundle] object.
#' @inheritParams plot3d
#' @returns An interactive [plotly] htmlwidget.
#' @seealso [plot3d()]
#' @name plot3d-fiber-bundle-method
#' @aliases plot3d,fiber::bundle-method
#' @usage NULL
S7::method(plot3d, fiber::bundle) <- function(
    x,
    color     = "orientation",
    palette   = "Viridis",
    linewidth = 2,
    opacity   = 0.5,
    ...) {
  n <- length(x@streamlines)
  cli::cli_alert_info("Rendering {n} streamline{?s}...")
  df <- .bundle_to_df(x)
  .plot3d_impl(
    df        = df,
    color     = color,
    palette   = palette,
    linewidth = linewidth,
    opacity   = opacity,
    ...
  )
}

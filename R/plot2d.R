# ---- internal helpers --------------------------------------------------------

# Column names used bare inside ggplot2::aes() NSE contexts; declared to keep
# R CMD check quiet (they are created by this file, not globals).
utils::globalVariables(c(".arclen", ".value", ".data"))

# Cumulative 3D arclength along a streamline's points, starting at 0. The
# last element is the streamline's total length.
.streamline_arclength <- function(x) {
  c(0, cumsum(sqrt(rowSums(diff(x)^2))))
}

# Number of equal-width chunks a streamline of `len` points is cut into.
# Cap the count so a short test streamline keeps one segment per point, while
# a 10k-point fibre does not flood the figure with points.
.n_chunks <- function(n_pts) {
  min(n_pts, max(5L, ceiling(n_pts / 8L)))
}

# Mean (or scalar broadcast) of a row-block of `df`, one chunk per return row.
# Averages every non-index column (`.chunk`, `.dist`, `.arclen` indexes are
# dropped), so per-chunk metadata is summarized with the geometry; columns
# whose values are constant within a chunk keep that value (e.g. per-streamline
# scalar metadata). `dist` is *total* per-chunk length (a sum, not a mean).
.chunk_summary <- function(df, chunks) {
  n_ch <- max(chunks)
  idx <- setdiff(names(df), c(".chunk", ".dist", ".arclen"))
  rows <- lapply(seq_len(n_ch), function(k) {
    block <- df[chunks == k, , drop = FALSE]
    if (nrow(block) == 0L) {
      return(NULL)
    }
    out <- lapply(idx, function(nm) {
      v <- block[[nm]]
      if (is.numeric(v)) {
        mean(v)
      } else {
        v[1L]
      }
    })
    names(out) <- idx
    out$.dist <- sum(block$.dist)
    out$.arclen <- block$.arclen[1L]
    out$.chunk <- k
    out
  })
  rows <- Filter(Negate(is.null), rows)
  do.call(rbind, lapply(rows, as.data.frame))
}

# ---- plot2d generic ----------------------------------------------------------

#' 2D arclength projection plots for tractography streamlines and bundles
#'
#' @description
#' `plot2d()` is an S7 generic that renders streamlines on a 2D canvas as a
#' **static [ggplot2] figure**: each streamline is re-parametrized by arc
#' length, so the horizontal axis is distance travelled along the fibre, and
#' the X / Y / Z coordinates are plotted against it in three vertically stacked
#' facets. This makes it easy to compare tract geometry against profiles of
#' diffusion measures such as FA or MD along the tract.
#'
#' Geometries are downsampled: points are grouped into equal-width chunks of
#' arclength (`n_chunks`, default 100), and each chunk contributes one mean
#' point. Scalar point attributes are averaged within each chunk; per-streamline
#' and per-bundle metadata are carried along unchanged.
#'
#' Methods are available for the following classes:
#'
#' `r doclisting::methods_list("plot2d")`
#'
#' @param x A [fiber::streamline], [fiber::bundle], or [fiber::bundle_set] object.
#' @param facet Character. Which coordinate columns to draw as facets. Defaults
#'   to `c("X", "Y", "Z")`, stacked top to bottom; pass `"X"` (or any subset)
#'   for a single facet.
#' @param color Controls how the line colour is assigned. Accepted values:
#'
#'   - `"orientation"` (default): point colour encodes the local fibre
#'     direction, mapped through the standard DTI
#'     (left–right = red, anterior–posterior = green, superior–inferior = blue)
#'     convention.
#'   - A **metadata key**: a string matching a key in `@point_data`
#'     (per-point scalar, averaged per chunk) or `@streamline_data` /
#'     `@bundle_data` (a single constant per streamline, broadcast to its
#'     points). Numeric values are mapped through `palette`; character values
#'     are coloured categorically. This is the natural way to overlay an FA or
#'     MD profile on a tract.
#'   - A **CSS/hex colour string**: e.g. `"#E69F00"` or `"steelblue"`. All
#'     lines are drawn in that fixed colour.
#' @param palette A colour scale name applied when `color` is a numeric metadata
#'   key. Resolved through `grDevices::hcl.colors()`. Defaults to `"Viridis"`.
#' @param n_chunks Numeric. Number of equal-arclength chunks to average each
#'   streamline into (default 100). Lower for lighter figures, higher for
#'   finer geometry. The chunk count is capped at the streamline's point count.
#' @param linewidth Numeric. Width of the drawn lines, in ggplot2 units (roughly
#'   millimetres). Defaults to `0.5`.
#' @param alpha Numeric in \[0, 1\]. Line opacity. Defaults to `1`.
#' @param ... Additional named arguments passed to [ggplot2::facet_wrap()] (for
#'   example `scales = "free_y"`).
#'
#' @returns A [ggplot2::ggplot()] figure with one facet per coordinate column.
#' @seealso [fiber::streamline], [fiber::bundle], [fiber::bundle_set],
#'   [plot3d()]
#' @export
#'
#' @examples
#' library(fiber)
#'
#' # A single fibre curving through 3-D space with a per-point FA profile.
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
#' # Stack the X / Y / Z coordinates against arclength.
#' plot2d(sl)
#'
#' # Overlay a per-point diffusion profile as the line colour.
#' plot2d(sl, color = "FA")
#'
#' # A fixed colour.
#' plot2d(sl, color = "steelblue")
#'
plot2d <- S7::new_generic(
  name = "plot2d",
  dispatch_args = "x",
  fun = function(
    x,
    facet = c("X", "Y", "Z"),
    color = "orientation",
    palette = "Viridis",
    n_chunks = 100L,
    linewidth = 0.5,
    alpha = 1,
    ...
  ) {
    S7::S7_dispatch()
  }
)

# ---- plot2d methods ----------------------------------------------------------

#' [plot2d()] method for `fiber::streamline` objects
#'
#' Renders a single [fiber::streamline] as a 2D arclength projection. See
#' [plot2d()] for the full parameter documentation and examples.
#'
#' @param x A [fiber::streamline] object.
#' @inheritParams plot2d
#' @returns A [ggplot2::ggplot()] figure with one facet per coordinate column.
#' @seealso [plot2d()]
#' @name plot2d-fiber-streamline-method
#' @aliases plot2d,fiber::streamline-method
#' @examples
#' library(fiber)
#'
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
#' plot2d(sl)
#' plot2d(sl, color = "FA")
#' plot2d(sl, color = "steelblue")
#'
S7::method(plot2d, fiber::streamline) <- function(
  x,
  facet = c("X", "Y", "Z"),
  color = "orientation",
  palette = "Viridis",
  n_chunks = 100L,
  linewidth = 0.5,
  alpha = 1,
  ...
) {
  df <- .streamline_to_df(x, streamline_id = 1L)
  .plot2d_impl(
    df = df,
    facet = facet,
    color = color,
    palette = palette,
    n_chunks = n_chunks,
    linewidth = linewidth,
    alpha = alpha,
    ...
  )
}

#' [plot2d()] method for `fiber::bundle` objects
#'
#' Renders all streamlines in a [fiber::bundle] as a 2D arclength projection.
#' See [plot2d()] for the full parameter documentation and examples.
#'
#' @param x A [fiber::bundle] object.
#' @inheritParams plot2d
#' @returns A [ggplot2::ggplot()] figure with one facet per coordinate column.
#' @seealso [plot2d()]
#' @name plot2d-fiber-bundle-method
#' @aliases plot2d,fiber::bundle-method
#' @examples
#' library(fiber)
#'
#' cst_sl <- function(i) {
#'   t   <- seq(-1, 1, length.out = 120)
#'   fan <- (t + 1) / 2
#'   streamline(
#'     cbind(
#'       X = 0.5 * sin(0.7 * t) + (i - 3.5) * 0.22 * (0.30 + 0.85 * fan),
#'       Y = 0.4 * cos(0.5 * t) + (i - 3.5) * 0.10 * (0.30 + 0.85 * fan),
#'       Z = 4 * t
#'     ),
#'     streamline_data = list(mean_FA = 0.4 + 0.08 * i)
#'   )
#' }
#' cst <- bundle(lapply(seq_len(8), cst_sl))
#'
#' plot2d(cst)
#' plot2d(cst, color = "mean_FA")
#'
S7::method(plot2d, fiber::bundle) <- function(
  x,
  facet = c("X", "Y", "Z"),
  color = "orientation",
  palette = "Viridis",
  n_chunks = 100L,
  linewidth = 0.5,
  alpha = 1,
  ...
) {
  n <- length(x@streamlines)
  cli::cli_alert_info("Rendering {n} streamline{?s}...")
  df <- .bundle_to_df(x)
  .plot2d_impl(
    df = df,
    facet = facet,
    color = color,
    palette = palette,
    n_chunks = n_chunks,
    linewidth = linewidth,
    alpha = alpha,
    ...
  )
}

#' [plot2d()] method for `fiber::bundle_set` objects
#'
#' Renders all bundles in a [fiber::bundle_set] as a 2D arclength projection,
#' with one facet per coordinate column. Each bundle can be coloured uniformly
#' by its bundle name or with the same per-streamline colouring as [plot2d()]
#' for [fiber::bundle] objects.
#'
#' @param x A [fiber::bundle_set] object.
#' @inheritParams plot2d
#' @param color_by_bundle Logical. When `TRUE`, every streamline is coloured by
#'   its parent bundle name (one distinct colour per entry in the set),
#'   overriding the `color` argument.
#' @returns A [ggplot2::ggplot()] figure with one facet per coordinate column.
#' @seealso [plot2d()]
#' @name plot2d-fiber-bundle_set-method
#' @aliases plot2d,fiber::bundle_set-method
#' @examples
#' library(fiber)
#'
#' cst_sl <- function(i) {
#'   t   <- seq(-1, 1, length.out = 120)
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
#' cst <- bundle(lapply(seq_len(8), cst_sl))
#' cc  <- bundle(lapply(seq_len(8), cc_sl))
#' cs  <- bundle_set(list(CST = cst, CC = cc))
#'
#' plot2d(cs)
#' plot2d(cs, color_by_bundle = TRUE)
#'
S7::method(plot2d, fiber::bundle_set) <- function(
  x,
  facet = c("X", "Y", "Z"),
  color = "orientation",
  palette = "Viridis",
  n_chunks = 100L,
  linewidth = 0.5,
  alpha = 1,
  color_by_bundle = FALSE,
  ...
) {
  n_bundles <- x@n_bundles
  n_sl <- sum(vapply(x@bundles, \(b) b@n_streamlines, integer(1L)))
  cli::cli_alert_info(
    "Rendering {n_sl} streamline{?s} across {n_bundles} bundle{?s}..."
  )
  df <- .bundle_set_to_df(x)
  .plot2d_impl(
    df = df,
    facet = facet,
    color = if (color_by_bundle) "BundleName" else color,
    palette = palette,
    n_chunks = n_chunks,
    linewidth = linewidth,
    alpha = alpha,
    ...
  )
}

# ---- plot2d implementation ---------------------------------------------------

# Shared workhorse behind the three plot2d() methods.
#
# Resolves the colour request into a `color` column, downsamples the geometry
# into equal-arclength chunks, and builds a faceted ggplot2 figure. Accepts
# the same colour vocabulary as plot3d() (orientation / metadata key / fixed
# colour).
.plot2d_impl <- function(
  df,
  facet = c("X", "Y", "Z"),
  color = "orientation",
  palette = "Viridis",
  n_chunks = 100L,
  linewidth = 0.5,
  alpha = 1,
  ...
) {
  facet <- match.arg(facet, several.ok = TRUE)
  if (!is_installed("ggplot2")) {
    stop(
      "plot2d() requires the 'ggplot2' package; install it with ",
      "install.packages('ggplot2').",
      call. = FALSE
    )
  }
  meta_keys <- setdiff(names(df), c("StreamlineId", "PointId", "X", "Y", "Z"))

  # ---- resolve colours ------------------------------------------------------
  if (identical(color, "orientation")) {
    cols <- lapply(split(df, df$StreamlineId), .color_by_orientation)
    df$.color <- unlist(cols, use.names = FALSE)
  } else if (color %in% meta_keys) {
    df$.color <- df[[color]]
    if (!is.numeric(df$.color)) {
      df$.color <- as.character(df$.color)
    }
  } else {
    # Treat as a fixed CSS / hex colour string
    df$.color <- rep_len(color, nrow(df))
  }

  # ---- downsample each streamline to n_chunks arclength means ---------------
  # Chunks of equal *distance travelled along the fibre* (not equal point
  # counts), so a densely-sampled wiggle contributes proportionally.
  parts <- split(df, df$StreamlineId)
  parts <- lapply(parts, function(p) {
    p$.arclen <- .streamline_arclength(as.matrix(p[c("X", "Y", "Z")]))
    p$.dist <- c(0, diff(p$.arclen))
    total <- p$.arclen[nrow(p)]
    n_ch <- min(n_chunks, .n_chunks(nrow(p)))
    # cut() does not suit a degenerate all-zero-total streamline (every
    # break is 0); chunk by points instead.
    bins <- seq(0, total, length.out = n_ch + 1L)
    cut_breaks <- unique(bins)
    if (length(cut_breaks) < 2L) {
      p$.chunk <- rep(seq_len(n_ch), length.out = nrow(p))
    } else {
      p$.chunk <- cut(
        p$.arclen,
        breaks = cut_breaks,
        labels = FALSE,
        include.lowest = TRUE
      )
    }
    .chunk_summary(p, p$.chunk)
  })
  df <- do.call(rbind, parts)

  # ---- reshape to long (one row per coordinate axis) -------------------------
  # Each chunk contributes one mean point; stack the requested coordinates so
  # facet_wrap(~axis) draws one panel per dimension, in `facet` order.
  long <- lapply(facet, function(ax) {
    out <- df
    out$axis <- factor(ax, levels = facet)
    out$.value <- out[[ax]]
    out
  })
  df <- do.call(rbind, long)

  # ---- build the faceted figure ---------------------------------------------
  # The colour aesthetic reads the resolved `.color` column (orientation /
  # fixed colours) or the metadata column itself (so the legend keeps the
  # user-facing name).
  nm_color <- if (color %in% meta_keys) color else ".color"
  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(x = .arclen, y = .value, group = .data$StreamlineId)
  )
  p <- p +
    ggplot2::geom_line(
      ggplot2::aes(color = .data[[nm_color]]),
      linewidth = linewidth,
      alpha = alpha
    )
  # Stack the coordinate facets; let the caller override (e.g. shared free
  # scales) via `...`.
  fw_args <- list(...)
  if (is.null(fw_args$scales)) {
    fw_args$scales <- "free_y"
  }
  p <- p +
    do.call(
      ggplot2::facet_wrap,
      c(list(facets = ~axis, ncol = 1L), fw_args)
    )
  p <- p + ggplot2::labs(x = "Arclength (mm)", y = "Coordinate")
  p <- p + ggplot2::theme_minimal()

  if (identical(color, "orientation")) {
    # DTI convention: orientation-coloured lines. Remove the legend swatch so
    # the figure itself carries the colour story (colour is per-segment local
    # tangent, not a single scale). `scale_color_identity` also maps the
    # literal hex values of a fixed colour.
    p <- p + ggplot2::scale_color_identity(guide = "none")
  } else if (color %in% meta_keys && is.numeric(df[[color]])) {
    p <- p +
      ggplot2::scale_color_gradientn(
        colors = grDevices::hcl.colors(256, palette = palette),
        name = color
      )
  } else if (color %in% meta_keys) {
    p <- p + ggplot2::scale_color_brewer(palette = "Set2", name = color)
  } else {
    # Fixed CSS/hex colour: draw every line in that literal colour rather than
    # mapping the string through the default discrete palette.
    p <- p + ggplot2::scale_color_identity(guide = "none")
  }
  p
}

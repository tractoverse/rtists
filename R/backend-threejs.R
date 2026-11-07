# ---- three.js backend -------------------------------------------------------
#
# Renders streamlines in the browser via three.js as an htmlwidget. This is the
# default backend for `plot3d()`: it supports real world-space line thickness
# (tubes) and object-level depth-sorted transparency, which the plotly backend
# cannot provide (WebGL core line width is capped at 1 in most browsers).
#
# The widget (`inst/htmlwidgets/rtists.js`) draws either:
#   * line mode  - a single `THREE.LineSegments` mesh (fast, large bundles), or
#   * tube mode  - one `THREE.TubeGeometry` per streamline with per-point
#                  colours and `depthWrite:false`, giving true thickness and
#                  object-level depth-sorted transparency.
#
# Verbatim vendored three.js (r128) + OrbitControls live under
# inst/htmlwidgets/lib/threejs/ and are declared in rtists.yaml, so the widget
# is fully self-contained (no CDN at render time).

# Convert a long rtists df back into the list-of-Nx3-matrices the widget wants.
# Rows are ordered by (StreamlineId, PointId); splitting preserves that.
.df_to_streamlines <- function(df) {
  if (is.null(df$StreamlineId)) {
    # A single streamline can arrive without ids (see .streamline_to_df).
    return(list(as.matrix(df[c("X", "Y", "Z")])))
  }
  parts <- split(df, df$StreamlineId)
  lapply(parts, function(p) as.matrix(p[c("X", "Y", "Z")]))
}

# Resolve the per-streamline colour vector from the resolved df + colour spec.
# Returns a character vector of length == number of streamlines (any CSS/hex
# colour), or the string "orientation" to pass through so the widget computes
# per-point DTI colours itself.
.df_resolve_colors <- function(df, color, palette, color_by_bundle = FALSE) {
  meta_keys <- setdiff(names(df), c("StreamlineId", "PointId", "X", "Y", "Z"))

  # bundle_set() threads a per-bundle category through `color_by_bundle`.
  if (color_by_bundle) {
    col <- df[[color]]                                   # e.g. "BundleName"
    key <- tapply(as.character(col), df$StreamlineId, function(v) v[1L])
    lvls <- unique(col)
    pal  <- grDevices::hcl.colors(length(lvls), palette = palette)
    return(unname(pal[match(key, lvls)]))
  }

  if (identical(color, "orientation")) {
    return("orientation")              # pass straight through to the widget
  }

  if (color %in% meta_keys) {
    val <- df[[color]]
    if (is.numeric(val)) {
      ## numeric metadata -> map its range onto the palette, one colour per sl.
      ## Guard against a zero span, and clamp the index into [1, 1000] so the
      ## minimum and maximum values always get a valid colour (a naive ceiling
      ## sends the minimum to index 0, silently dropping a streamline).
      ## Streamlines with an NA key (e.g. a metadata column absent from some
      ## bundles in a mixed set) are given a neutral grey instead of failing.
      key  <- tapply(val, df$StreamlineId, function(v) v[1L])
      ok   <- !is.na(key)
      pal  <- grDevices::hcl.colors(1000, palette = palette)
      out  <- rep("#888888", length(key))
      if (any(ok)) {
        key_ok <- key[ok]
        span   <- diff(range(key_ok))
        idx    <- if (span == 0) rep.int(1L, length(key_ok))
                  else 1L + ceiling(999 * (key_ok - min(key_ok)) / span)
        out[ok] <- pal[pmin(1000L, idx)]
      }
      return(out)
    }
    ## character / factor metadata -> categorical palette
    key  <- tapply(as.character(val), df$StreamlineId, function(v) v[1L])
    lvls <- unique(val)
    pal  <- grDevices::hcl.colors(length(lvls), palette = palette)
    return(unname(pal[match(key, lvls)]))
  }

  # Fixed CSS / hex colour string: recycle across streamlines.
  rep_len(color, length(unique(df$StreamlineId)))
}

# Resolve the radius request into a render mode and a per-point radius vector.
#
# `radius` accepts any of:
#   * `NULL` / empty: no radius, the fast `Line2` path at `linewidth` (default).
#   * a scalar `0`: fast flat `Line2` at `linewidth` (the "user prefers fast
#     lines" signal; nothing needs a tube).
#   * a positive scalar: every streamline is drawn as a true 3D `TubeGeometry`
#     of this constant world radius (per-point radii, Phong FlatShading).
#   * a per-streamline vector (length == number of streamlines): one constant
#     radius per line, expanded to per-point `TubeGeometry`.
#   * a per-point vector (length == total points): radius varying along each
#     streamline, `TubeGeometry` with radial displacement (most general form).
#
# Returns a list: `mode` ("line2" | "tube"), `radii` (per-point numeric vector,
# NULL when no radius is requested) and `linewidth` (world-units width to use in
# line2 mode).
.threejs_radius <- function(linewidth, radius, n_pts) {
  total <- sum(n_pts)

  if (is.null(radius) || length(radius) == 0L) {
    # No radius: default thin line2 at the requested linewidth.
    return(list(mode = "line2", radii = NULL, linewidth = linewidth))
  }

  if (length(radius) == 1L) {
    if (is.na(radius) || radius <= 0) {
      # Scalar 0 (or NA, or negative clamped) -> fast flat Line2.
      return(list(mode = "line2", radii = NULL, linewidth = linewidth))
    }
    # Positive scalar -> true constant-radius 3D tube (per-point radii).
    return(list(mode = "tube", radii = rep(radius, total), linewidth = linewidth))
  }

  if (length(radius) == length(n_pts)) {
    # Per-streamline constant radius -> expand to per-point.
    rpp <- unlist(Map(\(k, v) rep(v, k), n_pts, radius), use.names = FALSE)
  } else if (length(radius) == total) {
    rpp <- radius                   # per-point (most general)
  } else {
    stop(
      "`radius` must be a positive scalar, a per-streamline vector ",
      "(length == number of streamlines), or a per-point vector ",
      "(length == total number of points).",
      call. = FALSE
    )
  }
  if (anyNA(rpp) || any(rpp <= 0)) {
    stop("`radius` values must be positive.", call. = FALSE)
  }
  list(mode = "tube", radii = rpp, linewidth = linewidth)
}

# Build the rtists htmlwidget payload for a list of streamline matrices.
# `color` is either "orientation" (widget computes per-point DTI colours) or a
# per-streamline CSS/hex character vector (recycled). `mode` is "line2" (fast
# world-width lines, the default) or "tube" (per-streamline `TubeGeometry` with
# per-point radius via radial displacement).


.threejs_widget <- function(streamlines, color = "orientation",
                            linewidth = 1, radius = NULL,
                            opacity = 1, bg = "#111111", border = 0,
                            tooltip = NULL, legend = NULL, elementId = NULL) {
  if (!is.list(streamlines) || length(streamlines) == 0L) {
    stop("`streamlines` must be a non-empty list.", call. = FALSE)
  }
  streamlines <- lapply(streamlines, as.matrix)
  n_pts <- vapply(streamlines, nrow, integer(1L))

  rinfo <- .threejs_radius(linewidth, radius, n_pts)
  tube_mode <- identical(rinfo$mode, "tube")

  if (tube_mode) {
    # ---- tube mode: per-streamline points + per-point RGB ------------------
    n_pts <- vapply(streamlines, nrow, integer(1L))
    pos   <- numeric(3 * sum(n_pts))
    idx   <- 0L
    tubeOffsets <- integer(length(streamlines) + 1L)
    tubeOffsets[1L] <- 0L
    for (j in seq_along(streamlines)) {
      s <- streamlines[[j]]
      k <- nrow(s)
      pos[idx + seq_len(3 * k)] <- as.numeric(t(s))
      idx <- idx + 3 * k
      tubeOffsets[j + 1L] <- idx / 3L
    }
    # per-point RGB (3 per point)
    colors <- numeric(3 * sum(n_pts))
    if (identical(color, "orientation")) {
      ci <- 0L
      for (s in streamlines) {
        k <- nrow(s)
        d  <- rbind(0, diff(s))            # forward tangent per point
        d[k, ] <- d[k - 1L, ]
        nm <- sqrt(rowSums(d^2)); nm[nm == 0] <- 1
        rgb <- abs(d) / nm                 # |dx|,|dy|,|dz| -> R,G,B
        colors[ci + seq_len(3 * k)] <- as.numeric(t(rgb))
        ci <- ci + 3 * k
      }
    } else {
      colour_vec <- rep_len(color, length(streamlines))
      ci <- 0L
      for (j in seq_along(streamlines)) {
        k <- nrow(streamlines[[j]])
        rgb <- grDevices::col2rgb(colour_vec[j]) / 255
        colors[ci + seq_len(3 * k)] <- rep(as.numeric(rgb), k)
        ci <- ci + 3 * k
      }
    }
    # Positions/radii are packed as little-endian IEEE float32 and colors as
    # 8-bit channels (0-255); htmlwidgets base64-encodes the raw vectors into
    # compact strings instead of emitting ~17 decimal floats per point, and the
    # widget decodes them back on the JS side.
    x <- list(
      mode         = jsonlite::unbox("tube"),
      positions    = writeBin(pos, raw(), size = 4L),          # Float32 base64
      colors       = as.raw(pmin(255L, round(colors * 255))),  # Uint8 base64
      tubeOffsets  = tubeOffsets,                # cumulative point index
      n_pts        = n_pts,        # per-streamline point counts
      radii        = writeBin(rinfo$radii, raw(), size = 4L),  # Float32 base64
      linewidth    = jsonlite::unbox(linewidth), # scalar (unused in tube mode)
      border       = jsonlite::unbox(border),    # outline as a fraction of scene radius
      opacity      = jsonlite::unbox(opacity),
      bg           = jsonlite::unbox(bg)
    )
    if (!is.null(tooltip)) {
      x$tooltipData <- tooltip          # structured per-point metadata
    }
    if (!is.null(legend)) {
      x$legendData <- legend            # aesthetic-remapping metadata
    }

  } else {
    # ---- line2 mode: interleaved segment buffers (default, fast) ------------
    # Each pair (P_i, P_{i+1}) becomes one segment, so intermediate points are
    # emitted twice. This is a single big Float32Array we hand to three.js as one
    # `LineSegments2` draw call with `LineMaterial(worldUnits: true)`.
    # `linewidth` is the world-units constant width (or thin for no-radius).
    n_seg <- vapply(streamlines, function(s) nrow(s) - 1L, integer(1L))
    pos   <- numeric(6 * sum(n_seg))          # xyz xyz per segment
    idx   <- 0L
    for (s in streamlines) {
      k <- nrow(s)
      for (i in seq_len(k - 1L)) {
        pos[idx + 1L:3L] <- s[i,      ]
        pos[idx + 4L:6L] <- s[i + 1L, ]
        idx <- idx + 6L
      }
    }

    # ---- resolve colours (rgb per segment start/end vertex, 6/segment) ------
    # LineMaterial handles opacity globally, so we send rgb triples consumed by
    # LineSegmentsGeometry.setColors (instanceColorStart/End, 6 floats/segment).
    colors <- numeric(6 * sum(n_seg))
    if (identical(color, "orientation")) {
      ci <- 0L
      for (s in streamlines) {
        k <- nrow(s)
        for (i in seq_len(k - 1L)) {
          d <- s[i + 1L, ] - s[i, ]
          n <- sqrt(sum(d^2))
          if (n == 0) d <- c(1, 1, 1) else d <- d / n
          rgb <- abs(d)                        # DTI: |dx|,|dy|,|dz|
          colors[ci + 1L:6L] <- c(rgb, rgb)
          ci <- ci + 6L
        }
      }
    } else {
      colour_vec <- rep_len(color, length(streamlines))
      ci <- 0L
      for (j in seq_along(streamlines)) {
        s <- streamlines[[j]]
        k <- nrow(s)
        col <- grDevices::col2rgb(colour_vec[j]) / 255   # 3x1 in [0,1]
        for (i in seq_len(k - 1L)) {
          colors[ci + 1L:6L] <- rep(as.numeric(col), 2)
          ci <- ci + 6L
        }
      }
    }

    x <- list(
      mode      = jsonlite::unbox("line2"),
      positions = writeBin(pos, raw(), size = 4L),            # Float32 base64
      colors    = as.raw(pmin(255L, round(colors * 255))),    # Uint8 base64
      linewidth = jsonlite::unbox(rinfo$linewidth),   # world-units width
      n_pts     = n_pts,            # per-streamline point counts
      opacity   = jsonlite::unbox(opacity),           # scalar
      bg        = jsonlite::unbox(bg)                 # scalar
    )
    if (!is.null(tooltip)) {
      # Map each line2 segment (raycast `faceIndex`) to the packed point index
      # of its START vertex. Consecutive points within a streamline sit next to
      # each other in packed order, so the segment's end vertex is start + 1.
      pt_start <- c(0L, cumsum(n_pts)[-length(n_pts)])
      seg_to   <- integer(sum(n_seg))
      g        <- 0L
      for (j in seq_along(streamlines)) {
        nj <- nrow(streamlines[[j]]) - 1L
        if (nj >= 1L) seg_to[g + seq_len(nj)] <- pt_start[j] + seq_len(nj) - 1L
        g  <- g + nj
      }
      x$tooltipData <- tooltip          # structured per-point metadata
      x$segToPoint  <- seg_to           # line2 segment index -> point index
    }
    if (!is.null(legend)) {
      x$legendData <- legend            # aesthetic-remapping metadata
    }
  }

  htmlwidgets::createWidget(
    name      = "rtists",
    x         = x,
    package   = "rtists",
    elementId = elementId,
    sizingPolicy = htmlwidgets::sizingPolicy(
      viewer.padding = 0,
      browser.fill   = TRUE
    )
  )
}

# Shared dispatch for the three.js backend: a long df -> widget. `radius`
# accepts a positive scalar (true 3D tube), a scalar 0 (fast flat Line2), a
# per-streamline, or a per-point vector (radial-displacement tubes). `bg` is
# the scene background.

# Recover a tube radius carried on the streamline objects. A `radius` key in
# @point_data (per point) or @streamline_data (per streamline) is flattened by
# `.streamline_to_df()` into a `radius` column; return it as the per-streamline
# vector when it is constant within every streamline, or as the per-point
# vector when it varies along the fibres. Returns NULL when there is no usable
# positive radius (thin lines are then drawn).
.df_radius_from_data <- function(df) {
  r <- df$radius
  if (is.null(r) || anyNA(r) || any(r <= 0)) return(NULL)
  ids <- df$StreamlineId
  if (is.null(ids)) ids <- rep(1L, nrow(df))
  per_streamline <- tapply(r, ids, function(v) length(unique(v)) == 1L)
  if (all(per_streamline)) {
    key <- unname(tapply(r, ids, function(v) v[1L]))
    return(key)                         # per-streamline vector
  }
  r                                   # per-point vector
}

# Format one tooltip value: numeric values are trimmed to a compact width,
# everything else is shown as-is.
# Format tooltip values: numeric values are trimmed to a compact width,
# everything else is shown as-is. Vectorised (NA elements stay NA).
.df_tt_val <- function(v) {
  if (is.numeric(v)) {
    out <- as.character(signif(v, 4))
    out[is.na(v)] <- NA_character_
    out
  } else {
    v
  }
}

# Build the structured hover-tooltip payload for the three.js widget.
#
# `tooltip` is TRUE (bundle name + coordinates + all attribute columns), FALSE
# (disabled), or a character vector of attribute column names to restrict the
# initial selection to. Every attribute recorded on the object is already a df
# column (per-point, per-streamline, per-bundle, and per-bundle-set alike, plus
# the `BundleName` added by bundle_set()), so selecting them is a column pass
# over the resolved df; one row of `df` corresponds to one packed point.
#
# Returns a structured list consumed by the three.js renderer: `bundle` is the
# per-point bundle label (or NULL), `xyz` the per-point formatted coordinates
# (bundle name and coordinates are pinned and always shown), `columns` the
# toggleable attribute columns, `shown` their initial selection, and `values` a
# named list mapping each toggleable column to its per-point formatted display
# string. Returns NULL when the tooltip is disabled.
.df_tooltip_meta <- function(df, tooltip) {
  if (isFALSE(tooltip) || is.null(tooltip)) return(NULL)
  # The pinned columns (the bundle name and the coordinates, plus the internal
  # bookkeeping) are never offered as toggleable attribute columns.
  meta_cols <- setdiff(
    names(df),
    c("StreamlineId", "PointId", "X", "Y", "Z", ".color", ".hover", "BundleName")
  )
  if (isTRUE(tooltip)) {
    columns <- meta_cols
  } else {
    columns <- meta_cols                # all toggleable columns are offered...
  }
  shown <- if (isTRUE(tooltip)) columns else intersect(tooltip, columns)
  if (length(columns) == 0L) return(NULL)

  bundle_v <- df$BundleName
  bundle   <- if (!is.null(bundle_v)) as.character(bundle_v) else NULL
  xyz      <- sprintf(
    "X: %s  Y: %s  Z: %s",
    .df_tt_val(df$X), .df_tt_val(df$Y), .df_tt_val(df$Z)
  )
  values <- lapply(columns, function(k) {
    v <- df[[k]]
    out <- .df_tt_val(v)
    # blank empty values so rows with nothing to show render an empty line
    out[is.na(out) | (is.character(out) & out == "")] <- ""
    out
  })
  names(values) <- columns
  list(
    bundle  = bundle,
    xyz     = xyz,
    columns = columns,
    shown   = shown,
    values  = values
  )
}

# Build the structured legend payload for the three.js widget: the per-
# streamline point counts, the per-streamline bundle category, and the
# attribute columns usable for live aesthetic remapping (colour, tube radius,
# visibility). Columns are classified as streamline-scoped when they are
# constant within every streamline (this covers `@streamline_data` and
# `@bundle_data` columns, plus whole-column NA padding from union-binding) and
# point-scoped otherwise.
#
# The bundle name, the coordinates and the internal bookkeeping columns are
# never offered as aesthetics. `BundleName` is kept: it is the natural
# per-bundle colour / visibility key for bundle_set() objects.
#
# Returns a structured list consumed by the three.js renderer: `n_pts` the
# per-streamline point counts, `bundlePerSl` a per-streamline bundle category
# index (0 for the NA "no bundle" slot), `bundleNames` the category labels,
# `attrsPoint` a named list of point-scoped attribute series (numeric series
# packed as Float32 for compactness, anything else as a character vector),
# `attrsSl` a named list of streamline-scoped representative values, and `ramp`
# a 3x256 Uint8 colour ramp built from `palette`. Returns NULL when the object
# carries no attribute column.
.df_legend_meta <- function(df, palette = "Viridis") {
  base <- c("StreamlineId", "PointId", "X", "Y", "Z", ".color", ".hover")
  meta <- setdiff(names(df), base)
  if (length(meta) == 0L) return(NULL)

  ids <- df$StreamlineId
  if (is.null(ids)) ids <- rep(1L, nrow(df))
  grp <- factor(ids, levels = unique(ids))   # common group for split()/table()
  n_pts <- as.integer(unname(table(grp)))   # unnamed so jsonlite emits an array, not a named object

  bundle_v <- df$BundleName
  bundle_names <- if (!is.null(bundle_v)) unique(as.character(bundle_v)) else NULL
  bundlePerSl <- NULL
  if (!is.null(bundle_names)) {
    first <- function(x) { x <- x[!is.na(x)]; if (length(x)) x[1L] else NA_character_ }
    labels <- vapply(split(as.character(bundle_v), grp), first, character(1L))
    idx <- match(labels, bundle_names)
    idx[is.na(idx)] <- 0L
    bundlePerSl <- as.integer(idx)
  }

  first_rep <- function(x) {
    x <- x[!is.na(x)]
    if (length(x)) x[1L] else NA
  }
  pack_series <- function(v) {
    if (is.numeric(v)) writeBin(as.numeric(v), raw(), size = 4L)
    else as.character(v)
  }

  attrs_point <- list()
  attrs_sl    <- list()
  for (k in meta) {
    v <- df[[k]]
    const <- vapply(split(v, grp),
                    function(x) length(unique(x[!is.na(x)])) <= 1L,
                    logical(1L))
    if (all(const)) {
      attrs_sl[[k]] <- unlist(lapply(split(v, grp), first_rep), use.names = FALSE)
    } else {
      attrs_point[[k]] <- pack_series(v)
    }
  }

  ramp_mat <- grDevices::col2rgb(grDevices::hcl.colors(256, palette))
  list(
    n_pts       = n_pts,
    bundlePerSl = bundlePerSl,
    bundleNames = bundle_names,
    attrsPoint  = attrs_point,
    attrsSl     = attrs_sl,
    ramp        = as.raw(as.vector(ramp_mat))
  )
}

.plot3d_threejs <- function(df, color = "orientation", palette = "Viridis",
                            linewidth = 1, radius = NULL,
                            opacity = 1, bg = "#111111",
                            color_by_bundle = FALSE, tooltip = TRUE, ...) {
  legend_meta <- .df_legend_meta(df, palette)
  sls <- .df_to_streamlines(df)
  # Rely on the tube radius carried on the streamlines themselves: a `radius`
  # key in @point_data / @streamline_data is flattened into a df `radius`
  # column and is used when the caller did not pass an explicit `radius`.
  # rtists only reports the bundle in graphical form; it does not police
  # whether the tubes overlap (that is the generator's job, see prune()).
  if (is.null(radius) && !is.null(df$radius)) {
    radius <- .df_radius_from_data(df)
  }
  .threejs_widget(
    streamlines = sls,
    color       = .df_resolve_colors(df, color, palette, color_by_bundle),
    linewidth   = linewidth,
    radius      = radius,
    opacity     = opacity,
    bg          = bg,
    tooltip     = .df_tooltip_meta(df, tooltip),
    legend      = legend_meta,
    ...
  )
}

#' Shiny output / render functions for the three.js backend.
#'
#' @param outputId Output variable to read the widget from.
#' @param width,height Must be a valid CSS unit (like `"100%"`, `"400px"`,
#'   `"auto"`) or a number, which will be coerced to a string and have `"px"`
#'   appended.
#' @param expr An expression that generates an `rtists` widget.
#' @param env The environment in which to evaluate `expr`.
#' @param quoted Is `expr` a quoted expression?
#' @return An output or render function that enables use of the widget within
#'   Shiny applications.
#' @rdname rtists-shiny
#' @export
rtistsOutput <- function(outputId, width = "100%", height = "480px") {
  htmlwidgets::shinyWidgetOutput(outputId, "rtists", width, height,
                                 package = "rtists")
}
#' @rdname rtists-shiny
#' @export
renderRtists <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) { expr <- substitute(expr) }
  htmlwidgets::shinyRenderWidget(expr, rtistsOutput, env, quoted = TRUE)
}

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
      key  <- tapply(val, df$StreamlineId, function(v) v[1L])
      span <- diff(range(key))
      idx  <- if (span == 0) rep.int(1L, length(key))
              else 1L + ceiling(999 * (key - min(key)) / span)
      pal  <- grDevices::hcl.colors(1000, palette = palette)
      return(pal[pmin(1000L, idx)])
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
# Two knobs are supported to preserve backward compatibility while generalising
# to per-point radius:
#   * `thickness` (legacy scalar): when > 0 each streamline is drawn as a
#     `TubeGeometry` of this constant world radius. Retained so existing calls
#     and tests that passed `thickness` keep producing tube payloads.
#   * `radius` (new): accepts a positive scalar (constant world width, drawn as
#     `Line2` with `worldUnits: true`), a per-streamline vector (one constant
#     radius per line, `TubeGeometry`), or a per-point vector (variable radius,
#     `TubeGeometry` + radial displacement).
#
# Returns a list: `mode` ("line2" | "tube"), `radii` (per-point numeric vector,
# NULL when no radius is requested) and `linewidth` (world-units width to use in
# line2 mode). `prefer_line2` selects the fast Line2 path for constant radius.
.threejs_radius <- function(linewidth, thickness, radius, n_pts) {
  total <- sum(n_pts)

  # Which knob is in use? Explicit `radius` supersedes the legacy `thickness`.
  if (!is.null(radius) && length(radius) > 0L) {
    r <- radius
    prefer_line2 <- TRUE          # new API: constant radius -> cheap Line2
  } else if (length(thickness) == 1L && thickness > 0) {
    r <- thickness                # legacy API: keep tube behaviour
    prefer_line2 <- FALSE
  } else {
    return(list(mode = "line2", radii = NULL, linewidth = linewidth))
  }

  if (length(r) == 1L) {
    if (r <= 0) {
      return(list(mode = "line2", radii = NULL, linewidth = linewidth))
    }
    rpp <- rep(r, total)
    if (prefer_line2) {
      # constant world radius -> Line2 with worldUnits (cheap, single draw call)
      return(list(mode = "line2", radii = NULL, linewidth = r))
    }
    # legacy thickness -> constant-radius tube
    return(list(mode = "tube", radii = rpp, linewidth = linewidth))
  }

  if (length(r) == length(n_pts)) {
    # per-streamline constant radius -> expand to per-point
    rpp <- unlist(Map(\(k, v) rep(v, k), n_pts, r), use.names = FALSE)
  } else if (length(r) == total) {
    rpp <- r                        # per-point (most general)
  } else {
    stop(
      "`radius` must be a positive scalar, a per-streamline vector ",
      "(length == number of streamlines), or a per-point vector ",
      "(length == total number of points).",
      call. = FALSE
    )
  }
  if (any(rpp <= 0)) {
    stop("`radius` values must be positive.", call. = FALSE)
  }
  if (min(rpp) == max(rpp) && prefer_line2) {
    # effectively constant per-point radius -> fast Line2 world width
    return(list(mode = "line2", radii = NULL, linewidth = rpp[1L]))
  }
  list(mode = "tube", radii = rpp, linewidth = linewidth)
}

# Build the rtists htmlwidget payload for a list of streamline matrices.
# `color` is either "orientation" (widget computes per-point DTI colours) or a
# per-streamline CSS/hex character vector (recycled). `mode` is "line2" (fast
# world-width lines, the default) or "tube" (per-streamline `TubeGeometry` with
# per-point radius via radial displacement).

# Scene radius: half the largest spatial extent of all streamlines. Used to
# express the outline width (`border` x scene radius) in world units and to
# size the overlap cap.
.threejs_scene_radius <- function(streamlines) {
  all <- do.call(rbind, streamlines)
  ext <- vapply(c("X", "Y", "Z"), function(ax) {
    diff(range(all[, ax]))
  }, numeric(1L))
  max(0.5 * max(ext), 1e-6)
}

# Maximum radius that keeps a filled tube (radius + any optional outline) clear
# tubes. Returns NULL when there is only one streamline (nothing to collide).
.threejs_group_sep <- function(streamlines, ids) {
  if (length(ids) < 2L) return(Inf)
  sep <- Inf
  for (a in seq_along(ids)) {
    for (b in seq_along(ids)) {
      if (a >= b) next
      sep <- min(sep, .min_sep_two(streamlines[[ids[a]]], streamlines[[ids[b]]]))
    }
  }
  sep
}

.threejs_overlap_cap <- function(streamlines, border, groups = NULL) {
  m <- length(streamlines)
  if (m < 2L) return(NULL)
  dw <- border * .threejs_scene_radius(streamlines)
  # 0.9 leaves 10% clearance between nearest tubes; subtract any outline width.
  cap_of <- function(ids) {
    if (length(ids) < 2L) return(Inf)
    max(0, 0.9 * (.threejs_group_sep(streamlines, ids) / 2) - dw)
  }
  if (is.null(groups)) {
    return(list(max_radius = rep(cap_of(seq_len(m)), m)))
  }
  caps <- numeric(m)
  for (g in unique(groups)) {
    ids <- which(groups == g)
    caps[ids] <- cap_of(ids)
  }
  list(max_radius = caps)
}

.threejs_widget <- function(streamlines, color = "orientation",
                            linewidth = 1, thickness = 0, radius = NULL,
                            opacity = 1, bg = "#111111", border = 0,
                            groups = NULL, elementId = NULL) {
  if (!is.list(streamlines) || length(streamlines) == 0L) {
    stop("`streamlines` must be a non-empty list.", call. = FALSE)
  }
  streamlines <- lapply(streamlines, as.matrix)
  n_pts <- vapply(streamlines, nrow, integer(1L))

  rinfo <- .threejs_radius(linewidth, thickness, radius, n_pts)
  tube_mode <- identical(rinfo$mode, "tube")

  if (tube_mode) {
    # Thickness-positive tubes must not overlap: cap every radius (plus the
    # scene-relative outline width) at a fraction of the nearest approach
    # between distinct streamlines, emitting a message when a request gets
    # clamped so the user can tell why the tubes are not as fat as asked.
    clamp <- .threejs_overlap_cap(streamlines, border, groups)
    if (!is.null(clamp)) {
      # Expand the per-streamline cap to every point of that streamline.
      cap_pp <- rep(clamp$max_radius, times = n_pts)
      over <- rinfo$radii > cap_pp
      if (any(over)) {
        rinfo$radii[over] <- cap_pp[over]
        # Report the cap(s) actually applied: one per bundle that got clamped.
        ends <- cumsum(n_pts)
        starts <- ends - n_pts + 1L
        over_sl <- vapply(seq_along(n_pts), function(j)
          any(over[starts[j]:ends[j]]), logical(1L))
        applied <- unique(sort(clamp$max_radius[over_sl]))
        cli::cli_inform(
          "Thickness capped to {.val {applied}} so tubes do not overlap."
        )
      }
    }

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
    # Legacy scalar thickness is echoed back for backwards compatibility.
    # Positions/radii are packed as little-endian IEEE float32 and colors as
    # 8-bit channels (0-255); htmlwidgets base64-encodes the raw vectors into
    # compact strings instead of emitting ~17 decimal floats per point, and the
    # widget decodes them back on the JS side.
    x <- list(
      mode         = jsonlite::unbox("tube"),
      positions    = writeBin(pos, raw(), size = 4L),          # Float32 base64
      colors       = as.raw(pmin(255L, round(colors * 255))),  # Uint8 base64
      tubeOffsets  = tubeOffsets,                # cumulative point index
      radii        = writeBin(rinfo$radii, raw(), size = 4L),  # Float32 base64
      thickness    = jsonlite::unbox(thickness), # scalar (legacy echo)
      linewidth    = jsonlite::unbox(linewidth), # scalar (unused in tube mode)
      border       = jsonlite::unbox(border),    # outline as a fraction of scene radius
      opacity      = jsonlite::unbox(opacity),
      bg           = jsonlite::unbox(bg)
    )

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
      opacity   = jsonlite::unbox(opacity),           # scalar
      bg        = jsonlite::unbox(bg)                 # scalar
    )
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

# Shared dispatch for the three.js backend: a long df -> widget.
# `thickness` > 0 activates the legacy constant-radius tube mode. The newer
# `radius` argument accepts a scalar (Line2 world-width), per-streamline, or
# per-point vector (radial-displacement tubes). `bg` is the scene background.
.plot3d_threejs <- function(df, color = "orientation", palette = "Viridis",
                            linewidth = 1, thickness = 0, radius = NULL,
                            opacity = 1, bg = "#111111",
                            color_by_bundle = FALSE, ...) {
  sls <- .df_to_streamlines(df)
  # For a bundle_set the df carries one `BundleName` per streamline: thread it
  # through so the no-overlap cap is computed WITHIN each bundle, letting
  # distinct bundles that legitimately share space overlap without being shaved.
  groups <- NULL
  if (!is.null(df$BundleName)) {
    g <- tapply(as.character(df$BundleName), df$StreamlineId, function(v) v[1L])
    groups <- as.integer(factor(g, levels = unique(g)))
  }
  .threejs_widget(
    streamlines = sls,
    color       = .df_resolve_colors(df, color, palette, color_by_bundle),
    linewidth   = linewidth,
    thickness   = thickness,
    radius      = radius,
    opacity     = opacity,
    bg          = bg,
    groups      = groups,
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

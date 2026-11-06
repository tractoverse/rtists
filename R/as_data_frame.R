# S7 class names include the package prefix (e.g. "fiber::streamline"), so S3
# dispatch does NOT find methods registered under the bare name.  These are
# therefore plain internal helpers called directly by plot3d().

# rbind a list of data.frames, aligning every frame to the union of all
# their columns so that parts carrying different metadata (e.g. one bundle
# with a `radius` key and another with none) still combine. Absent columns
# are filled with NA.
.rbind_union <- function(parts) {
  cols <- unique(unlist(lapply(parts, names), use.names = FALSE))
  filled <- lapply(parts, function(p) {
    miss <- setdiff(cols, names(p))
    for (nm in miss) p[[nm]] <- NA_real_
    p[cols]
  })
  do.call(rbind, filled)
}

.streamline_to_df <- function(x, streamline_id = 1L) {
  n  <- nrow(x@points)
  df <- data.frame(
    StreamlineId = streamline_id,
    PointId      = seq_len(n),
    X            = x@points[, "X"],
    Y            = x@points[, "Y"],
    Z            = x@points[, "Z"]
  )
  for (nm in names(x@point_data)) {
    df[[nm]] <- x@point_data[[nm]]
  }
  for (nm in names(x@streamline_data)) {
    df[[nm]] <- x@streamline_data[[nm]]   # scalar recycled to nrow(df)
  }
  df
}

.bundle_to_df <- function(x) {
  n     <- length(x@streamlines)
  parts <- vector("list", n)
  for (i in seq_len(n)) {
    sl_df <- .streamline_to_df(x[[i]], streamline_id = i)
    # Broadcast scalar bundle_data as extra columns
    for (nm in names(x@bundle_data)) {
      val <- x@bundle_data[[nm]]
      if (length(val) == 1L && is.atomic(val)) {
        sl_df[[nm]] <- val
      }
    }
    parts[[i]] <- sl_df
  }
  .rbind_union(parts)
}

.bundle_set_to_df <- function(x, bundle_names = NULL) {
  if (is.null(bundle_names)) {
    # fiber::bundle_set() records per-bundle input names in @bundle_data under
    # "id_from_input_names" when the bundles were passed as a *named* list.
    if ("id_from_input_names" %in% names(x@bundle_data)) {
      nms <- x@bundle_data$id_from_input_names
    } else {
      nms <- seq_len(x@n_bundles)
    }
  } else {
    nms <- bundle_names
  }
  parts     <- vector("list", length(nms))
  sl_offset <- 0L
  for (i in seq_along(nms)) {
    bdf              <- .bundle_to_df(x@bundles[[i]])
    bdf$StreamlineId <- bdf$StreamlineId + sl_offset
    bdf$BundleName   <- nms[[i]]
    sl_offset        <- sl_offset + x@bundles[[i]]@n_streamlines
    parts[[i]]       <- bdf
  }
  .rbind_union(parts)
}

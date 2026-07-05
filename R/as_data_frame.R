# S7 class names include the package prefix (e.g. "fiber::streamline"), so S3
# dispatch does NOT find methods registered under the bare name.  These are
# therefore plain internal helpers called directly by plot3d().

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
  do.call(rbind, parts)
}

.bundle_set_to_df <- function(x) {
  nms       <- names(x@bundles)
  parts     <- vector("list", length(nms))
  sl_offset <- 0L
  for (i in seq_along(nms)) {
    bdf              <- .bundle_to_df(x@bundles[[i]])
    bdf$StreamlineId <- bdf$StreamlineId + sl_offset
    bdf$BundleName   <- nms[[i]]
    sl_offset        <- sl_offset + x@bundles[[i]]@n_streamlines
    parts[[i]]       <- bdf
  }
  do.call(rbind, parts)
}

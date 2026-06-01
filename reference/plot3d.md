# Interactive 3D line plot for tractography streamlines and bundles

`plot3d()` is an S7 generic that produces an interactive 3D line plot of
tractography objects from the
[fiber](https://tractoverse.github.io/fiber/) package using
[plotly](https://rdrr.io/pkg/plotly/man/plotly.html). Methods are
available for the following classes:

- [`fiber::bundle`](https://tractoverse.github.io/rtists/reference/plot3d-fiber-bundle-method.md)

- [`fiber::bundle_set`](https://tractoverse.github.io/rtists/reference/plot3d-fiber-bundle_set-method.md)

- [`fiber::streamline`](https://tractoverse.github.io/rtists/reference/plot3d-fiber-streamline-method.md)

All streamlines are rendered as a single `scatter3d` trace separated by
`NA` break-points, which keeps the widget lightweight even for large
bundles.

## Usage

``` r
plot3d(
  x,
  color = "orientation",
  palette = "Viridis",
  linewidth = 2,
  opacity = 0.5,
  ...
)
```

## Arguments

- x:

  A
  [fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html),
  [fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html),
  or
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  object.

- color:

  Controls how streamline colours are assigned. Accepted values:

  - `"orientation"` (default): per-point RGB colour derived from the
    local fibre direction. The absolute values of the normalised tangent
    vector \\(\|dx\|, \|dy\|, \|dz\|)\\ are mapped to the R, G, B
    channels — the standard DTI colour convention (left-right = red,
    anterior-posterior = green, superior-inferior = blue).

  - A **metadata key**: a string matching a key in `@point_data`
    (per-point scalar) or `@streamline_data` (per-streamline scalar,
    broadcast to all points). Numeric values are mapped to a continuous
    colour scale (`palette`); character values are coloured
    categorically.

  - A **CSS/hex colour string**: e.g. `"#E69F00"` or `"steelblue"`. All
    lines are drawn in that fixed colour.

- palette:

  A [plotly](https://rdrr.io/pkg/plotly/man/plotly.html) / ColorBrewer
  colour scale name applied when `color` is a numeric metadata key.
  Defaults to `"Viridis"`.

- linewidth:

  Numeric. Width of the plotted lines. Defaults to `2`.

- opacity:

  Numeric in \[0, 1\]. Global line opacity. Defaults to `0.5`.

- ...:

  Additional named arguments forwarded to `plotly::layout()`, e.g.
  `title = "My bundle"`.

## Value

An interactive [plotly](https://rdrr.io/pkg/plotly/man/plotly.html)
htmlwidget.

## See also

[fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html),
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)

## Examples

``` r
if (FALSE) { # \dontrun{
library(fiber)

# --- minimal streamline example -------------------------------------------
pts <- matrix(
  c(0, 0, 0,
    1, 1, 0,
    2, 1, 1,
    3, 2, 1),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)
sl <- streamline(
  points          = pts,
  point_data      = list(FA = c(0.3, 0.5, 0.7, 0.6)),
  streamline_data = list(mean_FA = 0.525)
)

# Default: colour by local fibre orientation
plot3d(sl)

# Colour by per-point FA (continuous colour scale)
plot3d(sl, color = "FA")

# Fixed colour
plot3d(sl, color = "steelblue", opacity = 0.8)

# --- bundle example -------------------------------------------------------
bun <- bundle(list(sl, sl))
plot3d(bun)
plot3d(bun, color = "mean_FA", palette = "RdYlBu")
} # }
```

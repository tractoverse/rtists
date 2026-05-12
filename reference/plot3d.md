# Interactive 3D line plot for tractography streamlines and bundles

Produce an interactive 3D line plot of a
[streamline](https://astamm.github.io/fiber/reference/streamline.html)
or [bundle](https://astamm.github.io/fiber/reference/bundle.html) object
from the fiber package using plotly.

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
  [streamline](https://astamm.github.io/fiber/reference/streamline.html)
  or [bundle](https://astamm.github.io/fiber/reference/bundle.html)
  object.

- color:

  Controls how streamline colours are assigned. Accepted values:

  `"orientation"` (default)

  :   Per-point RGB colour derived from the local fibre direction. The
      absolute values of the normalised tangent vector \\(\|dx\|,
      \|dy\|, \|dz\|)\\ are mapped to the R, G, B channels — the
      standard DTI colour convention (left–right = red,
      anterior–posterior = green, superior–inferior = blue).

  A **metadata key**

  :   A string that matches a key in `@point_data` (per-point scalar) or
      `@streamline_data` (per-streamline scalar, broadcast to all
      points). Numeric values are mapped to a continuous colour scale
      (`palette`); character values are coloured categorically.

  A **CSS/hex colour string**

  :   E.g. `"#E69F00"` or `"steelblue"`. All lines are drawn in that
      fixed colour.

- palette:

  A plotly / ColorBrewer colour scale name applied when `color` is a
  numeric metadata key. Defaults to `"Viridis"`.

- linewidth:

  Numeric. Width of the plotted lines. Defaults to `2`.

- opacity:

  Numeric in \[0, 1\]. Global line opacity. Defaults to `0.5`.

- ...:

  Additional named arguments forwarded to
  [`layout()`](https://rdrr.io/r/graphics/layout.html), e.g.
  `title = "My bundle"`.

## Value

An interactive plotly htmlwidget.

## Details

All streamlines are rendered as a single `scatter3d` trace separated by
`NA` break-points, which keeps the widget lightweight even for large
bundles.

## See also

[streamline](https://astamm.github.io/fiber/reference/streamline.html),
[bundle](https://astamm.github.io/fiber/reference/bundle.html)

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
sl <- new_streamline(
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
bun <- new_bundle(list(sl, sl))
plot3d(bun)
plot3d(bun, color = "mean_FA", palette = "RdYlBu")
} # }
```

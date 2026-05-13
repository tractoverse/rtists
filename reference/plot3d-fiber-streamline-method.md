# [`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md) method for `fiber::streamline` objects

Renders a single
[fiber::streamline](https://astamm.github.io/fiber/reference/streamline.html)
as an interactive 3D line plot. See
[`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md) for
the full parameter documentation and examples.

## Arguments

- x:

  A
  [fiber::streamline](https://astamm.github.io/fiber/reference/streamline.html)
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

[`plot3d()`](https://astamm.github.io/rtists/reference/plot3d.md)

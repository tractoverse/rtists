# [`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md) method for `fiber::streamline` objects

Renders a single
[fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html)
as an interactive 3D line plot. See
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
for the full parameter documentation and examples.

## Arguments

- x:

  A
  [fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html)
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

[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)

## Examples

``` r
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

{"x":{"visdat":{"1a534992fffe":["function () ","plotlyVisDat"]},"cur_data":"1a534992fffe","attrs":{"1a534992fffe":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":["#B4B400","#B400B4","#B4B400","#B4B400","rgba(0,0,0,0)"],"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Colour by per-point FA (continuous colour scale)
plot3d(sl, color = "FA")

{"x":{"visdat":{"1a53719fac27":["function () ","plotlyVisDat"]},"cur_data":"1a53719fac27","attrs":{"1a53719fac27":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":[0.29999999999999999,0.5,0.69999999999999996,0.59999999999999998,0],"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Fixed colour
plot3d(sl, color = "steelblue", opacity = 0.8)

{"x":{"visdat":{"1a532ff6dc10":["function () ","plotlyVisDat"]},"cur_data":"1a532ff6dc10","attrs":{"1a532ff6dc10":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.80000000000000004,"line":{"color":"steelblue","width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.80000000000000004,"line":{"color":"steelblue","width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
```

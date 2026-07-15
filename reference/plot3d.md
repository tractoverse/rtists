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

{"x":{"visdat":{"1a402cc22c1c":["function () ","plotlyVisDat"]},"cur_data":"1a402cc22c1c","attrs":{"1a402cc22c1c":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":["#B4B400","#B400B4","#B4B400","#B4B400","rgba(0,0,0,0)"],"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Colour by per-point FA (continuous colour scale)
plot3d(sl, color = "FA")

{"x":{"visdat":{"1a401f01c2bb":["function () ","plotlyVisDat"]},"cur_data":"1a401f01c2bb","attrs":{"1a401f01c2bb":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":[0.29999999999999999,0.5,0.69999999999999996,0.59999999999999998,0],"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# Fixed colour
plot3d(sl, color = "steelblue", opacity = 0.8)

{"x":{"visdat":{"1a404d55b752":["function () ","plotlyVisDat"]},"cur_data":"1a404d55b752","attrs":{"1a404d55b752":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.80000000000000004,"line":{"color":"steelblue","width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3],"y":[0,1,1,2],"z":[0,0,1,1],"mode":"lines","opacity":0.80000000000000004,"line":{"color":"steelblue","width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
# --- bundle example -------------------------------------------------------
bun <- bundle(list(sl, sl))
plot3d(bun)
#> ℹ Rendering 2 streamlines...

{"x":{"visdat":{"1a405a5afc13":["function () ","plotlyVisDat"]},"cur_data":"1a405a5afc13","attrs":{"1a405a5afc13":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3,null,0,1,2,3],"y":[0,1,1,2,null,0,1,1,2],"z":[0,0,1,1,null,0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":["#B4B400","#B400B4","#B4B400","#B4B400","rgba(0,0,0,0)","#B4B400","#B400B4","#B4B400","#B4B400","rgba(0,0,0,0)"],"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525",null,"FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text",null,"text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}plot3d(bun, color = "mean_FA", palette = "RdYlBu")
#> ℹ Rendering 2 streamlines...

{"x":{"visdat":{"1a4060bf1009":["function () ","plotlyVisDat"]},"cur_data":"1a4060bf1009","attrs":{"1a4060bf1009":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"colorscale":"RdYlBu","colorbar":{"title":"mean_FA"},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0,1,2,3,null,0,1,2,3],"y":[0,1,1,2,null,0,1,1,2],"z":[0,0,1,1,null,0,0,1,1],"mode":"lines","opacity":0.5,"line":{"color":[0.52500000000000002,0.52500000000000002,0.52500000000000002,0.52500000000000002,0,0.52500000000000002,0.52500000000000002,0.52500000000000002,0.52500000000000002,0],"colorscale":"RdYlBu","colorbar":{"title":"mean_FA"},"width":2},"text":["FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525",null,"FA: 0.3<br>mean_FA: 0.525","FA: 0.5<br>mean_FA: 0.525","FA: 0.7<br>mean_FA: 0.525","FA: 0.6<br>mean_FA: 0.525"],"hoverinfo":["text","text","text","text",null,"text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}
```



<link href="README_files/libs/htmltools-fill-0.5.9/fill.css" rel="stylesheet" />
<script src="README_files/libs/htmlwidgets-1.6.4/htmlwidgets.js"></script>
<script src="README_files/libs/plotly-binding-4.12.0/plotly.js"></script>
<script src="README_files/libs/setprototypeof-0.1/setprototypeof.js"></script>
<script src="README_files/libs/typedarray-0.1/typedarray.min.js"></script>
<script src="README_files/libs/jquery-3.5.1/jquery.min.js"></script>
<link href="README_files/libs/crosstalk-1.2.2/css/crosstalk.min.css" rel="stylesheet" />
<script src="README_files/libs/crosstalk-1.2.2/js/crosstalk.min.js"></script>
<link href="README_files/libs/plotly-htmlwidgets-css-2.25.2/plotly-htmlwidgets.css" rel="stylesheet" />
<script src="README_files/libs/plotly-main-2.25.2/plotly-latest.min.js"></script>

<!-- README.md is generated from README.qmd. Please edit that file -->

# rtists <a href="https://astamm.github.io/rtists/"><img src="man/figures/logo.png" align="right" height="138" alt="rtists website" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/astamm/rtists/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/astamm/rtists/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/astamm/rtists/graph/badge.svg)](https://app.codecov.io/gh/astamm/rtists)
[![pkgdown](https://github.com/astamm/rtists/actions/workflows/pkgdown.yaml/badge.svg)](https://github.com/astamm/rtists/actions/workflows/pkgdown.yaml)
<!-- badges: end -->

**rtists** (*R for Tissue Integrity Superimposed on Tractography
Streamlines*) provides interactive 3-D visualisation of tractography
streamlines and bundles defined in the
[fiber](https://github.com/astamm/fiber) package.

The main function is `plot3d()`, an
[S7](https://rconsortium.github.io/S7/) generic with methods for both
`fiber::streamline` and `fiber::bundle` objects. Figures are rendered by
[plotly](https://plotly.com/r/) and are fully interactive (pan, rotate,
zoom).

## Installation

Install the development version from
[GitHub](https://github.com/astamm/rtists):

``` r
# install.packages("pak")
pak::pak("astamm/rtists")
```

## Usage

### Build some fiber objects

``` r
library(rtists)
library(fiber)

pts <- matrix(
  c(
    0, 0, 0,
    1, 2, 1,
    2, 3, 3,
    3, 3, 5,
    4, 2, 6,
    5, 1, 7
  ),
  ncol = 3, byrow = TRUE,
  dimnames = list(NULL, c("X", "Y", "Z"))
)

sl <- new_streamline(
  points          = pts,
  point_data      = list(FA = c(0.25, 0.40, 0.65, 0.70, 0.55, 0.30)),
  streamline_data = list(mean_FA = 0.475)
)

set.seed(42)
bun <- new_bundle(lapply(seq_len(6), function(i) {
  noise <- matrix(rnorm(nrow(pts) * 3, sd = 0.2), ncol = 3)
  colnames(noise) <- c("X", "Y", "Z")
  new_streamline(
    points          = pts + noise,
    point_data      = list(FA = pmin(pmax(sl@point_data$FA + rnorm(6, sd = 0.05), 0), 1)),
    streamline_data = list(mean_FA = mean(sl@point_data$FA))
  )
}))
```

### `plot3d()` — colour modes

#### Default: orientation colours

Each point is coloured by the direction of the local tangent vector
using the standard DTI convention (left–right = red, anterior–posterior
= green, superior–inferior = blue):

``` r
plot3d(bun)
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-e8980251b4ee1bfbce5c" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-e8980251b4ee1bfbce5c">{"x":{"visdat":{"1169034f385b0":["function () ","plotlyVisDat"]},"cur_data":"1169034f385b0","attrs":{"1169034f385b0":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.2741916894293337,0.88706036572078228,2.0726256822674678,3.1265725209922079,4.0808536646281999,4.9787750967817033,null,0.37903869225299308,0.91390617367876004,1.948546123446214,2.6473673829610438,4.0920194709662541,4.8720010248079761,null,-0.086289240522669092,1.1311295766804412,2.0643850530407892,2.843232211823925,4.3151455039583952,5.1285798611434634,null,0.12470363239990873,0.8092953284455312,1.8914342370852286,3.1161992995363366,4.1536357475669181,5.0927535177080339,null,-0.22634773617075399,0.70815720009952088,2.015996510648232,3.1306408679298379,4.2401930751196986,5.2089502174335447,null,-0.29872501346325814,0.70591285171264073,2.0249404772394013,2.8006721730231927,3.9996354771390585,4.9143482237148373],"y":[0.30230439948778781,1.9810681923173805,3.4036847427754084,2.9874571801895158,2.2609739308446972,1.4573290785402213,null,0.091090024648243881,2.1409674674457637,3.2070207043939845,2.8782147249185579,2.100991024659594,0.6565982641853314,null,0.017952129319921128,2.0553101494582924,3.135857763211054,3.0179665773158164,1.401381983369413,1.0569765907061319,null,-0.17715525948193589,1.780043820270429,3.3025414019609856,3.0515842875064063,2.0176880458319171,0.97582069249218206,null,-0.20064172936796962,2.3696963803345494,2.8666453182484366,3.0211027624912137,1.9155488236262288,0.97552996560900573,null,-0.12273432128989903,1.5950644309161786,2.7550504099280029,3.0359032882235875,2.1135241188847069,0.90142452928930505],"z":[-0.27777214022246788,0.94424224663652567,2.9733357327212686,5.1271900796140146,5.9431494157167855,6.4687089158190449,null,-0.15689180167589928,0.82981848116469625,2.5171584700106733,5.0072245213784514,6.0411997200400505,6.9277885402902664,null,-0.073446928548195067,1.0370461129731219,3.1163647454731014,5.2799473654585354,5.8545415881051071,7.2605085264088292,null,-0.23886577903210565,1.1223993796080773,2.9565720308506958,4.9634486587336157,6.1866692657142321,7.1643546221016496,null,0.037638606900299576,1.0238321915994013,2.9949814898265195,5.0216145455884069,5.9029129528306665,6.8991565738624194,null,1.2576813070224817e-05,1.2245779286759932,3.2879711485952381,4.7805772463188356,5.9765360879499649,7.2402996801839405],"mode":"lines","opacity":0.5,"line":{"color":["#48C690","#6E84BC","#6E2CE2","#A8808F","#AE9C66","#AE9C66","rgba(0,0,0,0)","#3AE06C","#7579BF","#4420F4","#BE6688","#6BC579","#6BC579","rgba(0,0,0,0)","#76C66C","#5E6DD2","#560DF0","#A6B641","#7D35D8","#7D35D8","rgba(0,0,0,0)","#46C98C","#6994B3","#841BD8","#8B8AA3","#8C9B92","#8C9B92","rgba(0,0,0,0)","#52E156","#8A34D0","#7B11DF","#9D9D7D","#938F97","#938F97","rgba(0,0,0,0)","#6EBB86","#7C6DC2","#742ADF","#9F7A9E","#769CA3","#769CA3","rgba(0,0,0,0)"],"width":2},"text":["FA: 0.127976653571224<br>mean_FA: 0.475","FA: 0.46600566728651<br>mean_FA: 0.475","FA: 0.634668070296076<br>mean_FA: 0.475","FA: 0.610934578301<br>mean_FA: 0.475","FA: 0.541404132212019<br>mean_FA: 0.475","FA: 0.36073373495863<br>mean_FA: 0.475",null,"FA: 0.287908161784976<br>mean_FA: 0.475","FA: 0.363664758646171<br>mean_FA: 0.475","FA: 0.581585947779035<br>mean_FA: 0.475","FA: 0.721640901294436<br>mean_FA: 0.475","FA: 0.509430341190666<br>mean_FA: 0.475","FA: 0.372205063086063<br>mean_FA: 0.475",null,"FA: 0.266792405987604<br>mean_FA: 0.475","FA: 0.451925304934881<br>mean_FA: 0.475","FA: 0.696036428414532<br>mean_FA: 0.475","FA: 0.736043908143343<br>mean_FA: 0.475","FA: 0.497844053071607<br>mean_FA: 0.475","FA: 0.295490680669465<br>mean_FA: 0.475",null,"FA: 0.319605818796714<br>mean_FA: 0.475","FA: 0.376191303847266<br>mean_FA: 0.475","FA: 0.682517428036315<br>mean_FA: 0.475","FA: 0.7695555228195<br>mean_FA: 0.475","FA: 0.494460556027605<br>mean_FA: 0.475","FA: 0.256960370656108<br>mean_FA: 0.475",null,"FA: 0.166945046004259<br>mean_FA: 0.475","FA: 0.380883313656309<br>mean_FA: 0.475","FA: 0.62436748710611<br>mean_FA: 0.475","FA: 0.83509455001724<br>mean_FA: 0.475","FA: 0.481894188440514<br>mean_FA: 0.475","FA: 0.30686281092793<br>mean_FA: 0.475",null,"FA: 0.226513520971685<br>mean_FA: 0.475","FA: 0.39737652575305<br>mean_FA: 0.475","FA: 0.645694635088146<br>mean_FA: 0.475","FA: 0.655616049104678<br>mean_FA: 0.475","FA: 0.527765799755763<br>mean_FA: 0.475","FA: 0.298527756045588<br>mean_FA: 0.475"],"hoverinfo":["text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

#### Colour by per-point metadata

Pass any key from `@point_data` to map a continuous scalar to a colour
scale:

``` r
plot3d(bun, color = "FA", palette = "Viridis")
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-3853d8cf75d7e03c65aa" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-3853d8cf75d7e03c65aa">{"x":{"visdat":{"116903911321e":["function () ","plotlyVisDat"]},"cur_data":"116903911321e","attrs":{"116903911321e":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.2741916894293337,0.88706036572078228,2.0726256822674678,3.1265725209922079,4.0808536646281999,4.9787750967817033,null,0.37903869225299308,0.91390617367876004,1.948546123446214,2.6473673829610438,4.0920194709662541,4.8720010248079761,null,-0.086289240522669092,1.1311295766804412,2.0643850530407892,2.843232211823925,4.3151455039583952,5.1285798611434634,null,0.12470363239990873,0.8092953284455312,1.8914342370852286,3.1161992995363366,4.1536357475669181,5.0927535177080339,null,-0.22634773617075399,0.70815720009952088,2.015996510648232,3.1306408679298379,4.2401930751196986,5.2089502174335447,null,-0.29872501346325814,0.70591285171264073,2.0249404772394013,2.8006721730231927,3.9996354771390585,4.9143482237148373],"y":[0.30230439948778781,1.9810681923173805,3.4036847427754084,2.9874571801895158,2.2609739308446972,1.4573290785402213,null,0.091090024648243881,2.1409674674457637,3.2070207043939845,2.8782147249185579,2.100991024659594,0.6565982641853314,null,0.017952129319921128,2.0553101494582924,3.135857763211054,3.0179665773158164,1.401381983369413,1.0569765907061319,null,-0.17715525948193589,1.780043820270429,3.3025414019609856,3.0515842875064063,2.0176880458319171,0.97582069249218206,null,-0.20064172936796962,2.3696963803345494,2.8666453182484366,3.0211027624912137,1.9155488236262288,0.97552996560900573,null,-0.12273432128989903,1.5950644309161786,2.7550504099280029,3.0359032882235875,2.1135241188847069,0.90142452928930505],"z":[-0.27777214022246788,0.94424224663652567,2.9733357327212686,5.1271900796140146,5.9431494157167855,6.4687089158190449,null,-0.15689180167589928,0.82981848116469625,2.5171584700106733,5.0072245213784514,6.0411997200400505,6.9277885402902664,null,-0.073446928548195067,1.0370461129731219,3.1163647454731014,5.2799473654585354,5.8545415881051071,7.2605085264088292,null,-0.23886577903210565,1.1223993796080773,2.9565720308506958,4.9634486587336157,6.1866692657142321,7.1643546221016496,null,0.037638606900299576,1.0238321915994013,2.9949814898265195,5.0216145455884069,5.9029129528306665,6.8991565738624194,null,1.2576813070224817e-05,1.2245779286759932,3.2879711485952381,4.7805772463188356,5.9765360879499649,7.2402996801839405],"mode":"lines","opacity":0.5,"line":{"color":[0.12797665357122406,0.46600566728650961,0.6346680702960763,0.61093457830099995,0.541404132212019,0.36073373495862993,0,0.28790816178497586,0.36366475864617126,0.58158594777903527,0.72164090129443581,0.50943034119066644,0.3722050630860626,0,0.26679240598760373,0.45192530493488109,0.69603642841453239,0.73604390814334308,0.49784405307160728,0.29549068066946466,0,0.31960581879671357,0.37619130384726629,0.68251742803631532,0.76955552281950002,0.49446055602760508,0.25696037065610788,0,0.16694504600425941,0.38088331365630912,0.62436748710611001,0.83509455001723987,0.48189418844051413,0.30686281092793033,0,0.22651352097168495,0.39737652575305021,0.64569463508814551,0.65561604910467841,0.5277657997557631,0.29852775604558807,0],"colorscale":"Viridis","colorbar":{"title":"FA"},"width":2},"text":["FA: 0.127976653571224<br>mean_FA: 0.475","FA: 0.46600566728651<br>mean_FA: 0.475","FA: 0.634668070296076<br>mean_FA: 0.475","FA: 0.610934578301<br>mean_FA: 0.475","FA: 0.541404132212019<br>mean_FA: 0.475","FA: 0.36073373495863<br>mean_FA: 0.475",null,"FA: 0.287908161784976<br>mean_FA: 0.475","FA: 0.363664758646171<br>mean_FA: 0.475","FA: 0.581585947779035<br>mean_FA: 0.475","FA: 0.721640901294436<br>mean_FA: 0.475","FA: 0.509430341190666<br>mean_FA: 0.475","FA: 0.372205063086063<br>mean_FA: 0.475",null,"FA: 0.266792405987604<br>mean_FA: 0.475","FA: 0.451925304934881<br>mean_FA: 0.475","FA: 0.696036428414532<br>mean_FA: 0.475","FA: 0.736043908143343<br>mean_FA: 0.475","FA: 0.497844053071607<br>mean_FA: 0.475","FA: 0.295490680669465<br>mean_FA: 0.475",null,"FA: 0.319605818796714<br>mean_FA: 0.475","FA: 0.376191303847266<br>mean_FA: 0.475","FA: 0.682517428036315<br>mean_FA: 0.475","FA: 0.7695555228195<br>mean_FA: 0.475","FA: 0.494460556027605<br>mean_FA: 0.475","FA: 0.256960370656108<br>mean_FA: 0.475",null,"FA: 0.166945046004259<br>mean_FA: 0.475","FA: 0.380883313656309<br>mean_FA: 0.475","FA: 0.62436748710611<br>mean_FA: 0.475","FA: 0.83509455001724<br>mean_FA: 0.475","FA: 0.481894188440514<br>mean_FA: 0.475","FA: 0.30686281092793<br>mean_FA: 0.475",null,"FA: 0.226513520971685<br>mean_FA: 0.475","FA: 0.39737652575305<br>mean_FA: 0.475","FA: 0.645694635088146<br>mean_FA: 0.475","FA: 0.655616049104678<br>mean_FA: 0.475","FA: 0.527765799755763<br>mean_FA: 0.475","FA: 0.298527756045588<br>mean_FA: 0.475"],"hoverinfo":["text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

#### Colour by per-streamline metadata

Keys from `@streamline_data` are broadcast to all points of each
streamline, giving every tract a single uniform colour:

``` r
plot3d(bun, color = "mean_FA", palette = "RdYlBu")
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-e89599b535d33635fe39" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-e89599b535d33635fe39">{"x":{"visdat":{"116902bd06caa":["function () ","plotlyVisDat"]},"cur_data":"116902bd06caa","attrs":{"116902bd06caa":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.5,"line":{"color":{},"colorscale":"RdYlBu","colorbar":{"title":"mean_FA"},"width":2},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.2741916894293337,0.88706036572078228,2.0726256822674678,3.1265725209922079,4.0808536646281999,4.9787750967817033,null,0.37903869225299308,0.91390617367876004,1.948546123446214,2.6473673829610438,4.0920194709662541,4.8720010248079761,null,-0.086289240522669092,1.1311295766804412,2.0643850530407892,2.843232211823925,4.3151455039583952,5.1285798611434634,null,0.12470363239990873,0.8092953284455312,1.8914342370852286,3.1161992995363366,4.1536357475669181,5.0927535177080339,null,-0.22634773617075399,0.70815720009952088,2.015996510648232,3.1306408679298379,4.2401930751196986,5.2089502174335447,null,-0.29872501346325814,0.70591285171264073,2.0249404772394013,2.8006721730231927,3.9996354771390585,4.9143482237148373],"y":[0.30230439948778781,1.9810681923173805,3.4036847427754084,2.9874571801895158,2.2609739308446972,1.4573290785402213,null,0.091090024648243881,2.1409674674457637,3.2070207043939845,2.8782147249185579,2.100991024659594,0.6565982641853314,null,0.017952129319921128,2.0553101494582924,3.135857763211054,3.0179665773158164,1.401381983369413,1.0569765907061319,null,-0.17715525948193589,1.780043820270429,3.3025414019609856,3.0515842875064063,2.0176880458319171,0.97582069249218206,null,-0.20064172936796962,2.3696963803345494,2.8666453182484366,3.0211027624912137,1.9155488236262288,0.97552996560900573,null,-0.12273432128989903,1.5950644309161786,2.7550504099280029,3.0359032882235875,2.1135241188847069,0.90142452928930505],"z":[-0.27777214022246788,0.94424224663652567,2.9733357327212686,5.1271900796140146,5.9431494157167855,6.4687089158190449,null,-0.15689180167589928,0.82981848116469625,2.5171584700106733,5.0072245213784514,6.0411997200400505,6.9277885402902664,null,-0.073446928548195067,1.0370461129731219,3.1163647454731014,5.2799473654585354,5.8545415881051071,7.2605085264088292,null,-0.23886577903210565,1.1223993796080773,2.9565720308506958,4.9634486587336157,6.1866692657142321,7.1643546221016496,null,0.037638606900299576,1.0238321915994013,2.9949814898265195,5.0216145455884069,5.9029129528306665,6.8991565738624194,null,1.2576813070224817e-05,1.2245779286759932,3.2879711485952381,4.7805772463188356,5.9765360879499649,7.2402996801839405],"mode":"lines","opacity":0.5,"line":{"color":[0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0.47499999999999998,0],"colorscale":"RdYlBu","colorbar":{"title":"mean_FA"},"width":2},"text":["FA: 0.127976653571224<br>mean_FA: 0.475","FA: 0.46600566728651<br>mean_FA: 0.475","FA: 0.634668070296076<br>mean_FA: 0.475","FA: 0.610934578301<br>mean_FA: 0.475","FA: 0.541404132212019<br>mean_FA: 0.475","FA: 0.36073373495863<br>mean_FA: 0.475",null,"FA: 0.287908161784976<br>mean_FA: 0.475","FA: 0.363664758646171<br>mean_FA: 0.475","FA: 0.581585947779035<br>mean_FA: 0.475","FA: 0.721640901294436<br>mean_FA: 0.475","FA: 0.509430341190666<br>mean_FA: 0.475","FA: 0.372205063086063<br>mean_FA: 0.475",null,"FA: 0.266792405987604<br>mean_FA: 0.475","FA: 0.451925304934881<br>mean_FA: 0.475","FA: 0.696036428414532<br>mean_FA: 0.475","FA: 0.736043908143343<br>mean_FA: 0.475","FA: 0.497844053071607<br>mean_FA: 0.475","FA: 0.295490680669465<br>mean_FA: 0.475",null,"FA: 0.319605818796714<br>mean_FA: 0.475","FA: 0.376191303847266<br>mean_FA: 0.475","FA: 0.682517428036315<br>mean_FA: 0.475","FA: 0.7695555228195<br>mean_FA: 0.475","FA: 0.494460556027605<br>mean_FA: 0.475","FA: 0.256960370656108<br>mean_FA: 0.475",null,"FA: 0.166945046004259<br>mean_FA: 0.475","FA: 0.380883313656309<br>mean_FA: 0.475","FA: 0.62436748710611<br>mean_FA: 0.475","FA: 0.83509455001724<br>mean_FA: 0.475","FA: 0.481894188440514<br>mean_FA: 0.475","FA: 0.30686281092793<br>mean_FA: 0.475",null,"FA: 0.226513520971685<br>mean_FA: 0.475","FA: 0.39737652575305<br>mean_FA: 0.475","FA: 0.645694635088146<br>mean_FA: 0.475","FA: 0.655616049104678<br>mean_FA: 0.475","FA: 0.527765799755763<br>mean_FA: 0.475","FA: 0.298527756045588<br>mean_FA: 0.475"],"hoverinfo":["text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

#### Fixed colour

Any CSS colour name or hex code colours all lines identically:

``` r
plot3d(bun, color = "steelblue", opacity = 0.7, linewidth = 3)
```

<div class="plotly html-widget html-fill-item" id="htmlwidget-aca42ace54a19865c08d" style="width:672px;height:480px;"></div>
<script type="application/json" data-for="htmlwidget-aca42ace54a19865c08d">{"x":{"visdat":{"116903b4f84bf":["function () ","plotlyVisDat"]},"cur_data":"116903b4f84bf","attrs":{"116903b4f84bf":{"x":{},"y":{},"z":{},"mode":"lines","opacity":0.69999999999999996,"line":{"color":"steelblue","width":3},"text":{},"hoverinfo":"text","alpha_stroke":1,"sizes":[10,100],"spans":[1,20],"type":"scatter3d"}},"layout":{"margin":{"b":40,"l":60,"t":25,"r":10},"scene":{"xaxis":{"title":"X (mm)"},"yaxis":{"title":"Y (mm)"},"zaxis":{"title":"Z (mm)"},"aspectmode":"data"},"hovermode":"closest","showlegend":false},"source":"A","config":{"modeBarButtonsToAdd":["hoverclosest","hovercompare"],"showSendToCloud":false},"data":[{"x":[0.2741916894293337,0.88706036572078228,2.0726256822674678,3.1265725209922079,4.0808536646281999,4.9787750967817033,null,0.37903869225299308,0.91390617367876004,1.948546123446214,2.6473673829610438,4.0920194709662541,4.8720010248079761,null,-0.086289240522669092,1.1311295766804412,2.0643850530407892,2.843232211823925,4.3151455039583952,5.1285798611434634,null,0.12470363239990873,0.8092953284455312,1.8914342370852286,3.1161992995363366,4.1536357475669181,5.0927535177080339,null,-0.22634773617075399,0.70815720009952088,2.015996510648232,3.1306408679298379,4.2401930751196986,5.2089502174335447,null,-0.29872501346325814,0.70591285171264073,2.0249404772394013,2.8006721730231927,3.9996354771390585,4.9143482237148373],"y":[0.30230439948778781,1.9810681923173805,3.4036847427754084,2.9874571801895158,2.2609739308446972,1.4573290785402213,null,0.091090024648243881,2.1409674674457637,3.2070207043939845,2.8782147249185579,2.100991024659594,0.6565982641853314,null,0.017952129319921128,2.0553101494582924,3.135857763211054,3.0179665773158164,1.401381983369413,1.0569765907061319,null,-0.17715525948193589,1.780043820270429,3.3025414019609856,3.0515842875064063,2.0176880458319171,0.97582069249218206,null,-0.20064172936796962,2.3696963803345494,2.8666453182484366,3.0211027624912137,1.9155488236262288,0.97552996560900573,null,-0.12273432128989903,1.5950644309161786,2.7550504099280029,3.0359032882235875,2.1135241188847069,0.90142452928930505],"z":[-0.27777214022246788,0.94424224663652567,2.9733357327212686,5.1271900796140146,5.9431494157167855,6.4687089158190449,null,-0.15689180167589928,0.82981848116469625,2.5171584700106733,5.0072245213784514,6.0411997200400505,6.9277885402902664,null,-0.073446928548195067,1.0370461129731219,3.1163647454731014,5.2799473654585354,5.8545415881051071,7.2605085264088292,null,-0.23886577903210565,1.1223993796080773,2.9565720308506958,4.9634486587336157,6.1866692657142321,7.1643546221016496,null,0.037638606900299576,1.0238321915994013,2.9949814898265195,5.0216145455884069,5.9029129528306665,6.8991565738624194,null,1.2576813070224817e-05,1.2245779286759932,3.2879711485952381,4.7805772463188356,5.9765360879499649,7.2402996801839405],"mode":"lines","opacity":0.69999999999999996,"line":{"color":"steelblue","width":3},"text":["FA: 0.127976653571224<br>mean_FA: 0.475","FA: 0.46600566728651<br>mean_FA: 0.475","FA: 0.634668070296076<br>mean_FA: 0.475","FA: 0.610934578301<br>mean_FA: 0.475","FA: 0.541404132212019<br>mean_FA: 0.475","FA: 0.36073373495863<br>mean_FA: 0.475",null,"FA: 0.287908161784976<br>mean_FA: 0.475","FA: 0.363664758646171<br>mean_FA: 0.475","FA: 0.581585947779035<br>mean_FA: 0.475","FA: 0.721640901294436<br>mean_FA: 0.475","FA: 0.509430341190666<br>mean_FA: 0.475","FA: 0.372205063086063<br>mean_FA: 0.475",null,"FA: 0.266792405987604<br>mean_FA: 0.475","FA: 0.451925304934881<br>mean_FA: 0.475","FA: 0.696036428414532<br>mean_FA: 0.475","FA: 0.736043908143343<br>mean_FA: 0.475","FA: 0.497844053071607<br>mean_FA: 0.475","FA: 0.295490680669465<br>mean_FA: 0.475",null,"FA: 0.319605818796714<br>mean_FA: 0.475","FA: 0.376191303847266<br>mean_FA: 0.475","FA: 0.682517428036315<br>mean_FA: 0.475","FA: 0.7695555228195<br>mean_FA: 0.475","FA: 0.494460556027605<br>mean_FA: 0.475","FA: 0.256960370656108<br>mean_FA: 0.475",null,"FA: 0.166945046004259<br>mean_FA: 0.475","FA: 0.380883313656309<br>mean_FA: 0.475","FA: 0.62436748710611<br>mean_FA: 0.475","FA: 0.83509455001724<br>mean_FA: 0.475","FA: 0.481894188440514<br>mean_FA: 0.475","FA: 0.30686281092793<br>mean_FA: 0.475",null,"FA: 0.226513520971685<br>mean_FA: 0.475","FA: 0.39737652575305<br>mean_FA: 0.475","FA: 0.645694635088146<br>mean_FA: 0.475","FA: 0.655616049104678<br>mean_FA: 0.475","FA: 0.527765799755763<br>mean_FA: 0.475","FA: 0.298527756045588<br>mean_FA: 0.475"],"hoverinfo":["text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text",null,"text","text","text","text","text","text"],"type":"scatter3d","marker":{"color":"rgba(31,119,180,1)","line":{"color":"rgba(31,119,180,1)"}},"error_y":{"color":"rgba(31,119,180,1)"},"error_x":{"color":"rgba(31,119,180,1)"},"frame":null}],"highlight":{"on":"plotly_click","persistent":false,"dynamic":false,"selectize":false,"opacityDim":0.20000000000000001,"selected":{"opacity":1},"debounce":0},"shinyEvents":["plotly_hover","plotly_click","plotly_selected","plotly_relayout","plotly_brushed","plotly_brushing","plotly_clickannotation","plotly_doubleclick","plotly_deselect","plotly_afterplot","plotly_sunburstclick"],"base_url":"https://plot.ly"},"evals":[],"jsHooks":[]}</script>

## Colour modes at a glance

| `color` value | Behaviour |
|----|----|
| `"orientation"` (default) | Per-point RGB from local fibre direction |
| Name of a `@point_data` key | Continuous or categorical scale per point |
| Name of a `@streamline_data` key | Uniform colour per streamline |
| CSS / hex string (e.g. `"steelblue"`) | Fixed colour for all lines |

Additional arguments (`palette`, `linewidth`, `opacity`, `...`) are
documented in `?plot3d`.

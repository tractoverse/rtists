# rtists 0.1.0

* Initial CRAN release.
* Added `plot3d()`, an [S7](https://rconsortium.github.io/S7/) generic with
  methods for `fiber::streamline`, `fiber::bundle`, and `fiber::bundle_set`
  objects.
* Two htmlwidget backends are available through `backend` (three.js is the
  default):
  - `"threejs"`: a self-contained three.js renderer (no CDN). `thickness > 0`
    draws real world-space tubes with per-point colour and object-level
    depth-sorted transparency; the fast line mode scales to large bundles.
  - `"plotly"`: a single `scatter3d` trace separated by `NA` break-points,
    retained as an interim fallback.
* Colour modes supported by `plot3d()`:
  - `"orientation"` (default): per-point RGB colour derived from the local
    fibre direction using the standard DTI convention
    (left–right = red, anterior–posterior = green, superior–inferior = blue).
  - Metadata key: any key from `@point_data` or `@streamline_data` can be
    mapped to a continuous (`palette`) or categorical colour scale.
  - Fixed colour: any CSS colour name or hex string.
* Interactive figures support pan, rotate, and zoom.

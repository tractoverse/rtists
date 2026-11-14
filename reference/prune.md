# Prune a tractography bundle to non-overlapping, hull-covering tubes

`prune()` is the low-level, tunable engine behind
[`fatten()`](https://tractoverse.github.io/rtists/reference/fatten.md):
it thins a
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
(or a
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html))
down to a subset of streamlines that can be rendered as fat
non-overlapping tubes, from a tube `radius` and `overlap_margin` that
*you* choose. Reach for `prune()` directly when you want full control
over the tube size and the clearance between tubes (the argument-driven
path); reach for
[`fatten()`](https://tractoverse.github.io/rtists/reference/fatten.md)
when you would rather rtists pick a visible radius for you, in which
case it calls this same selection logic internally. Use it when *you*
build the tubes yourself, from streamlines that carry no per-point or
per-streamline radius: you choose a single tube `radius`, and `prune()`
keeps as many streamlines as possible such that:

- any two kept tubes (radius plus `overlap_margin` clearance) stay clear
  of each other, and

- the kept tubes still cover the whole convex hull of the original
  bundle (every point lies within `radius` of a kept tube).

[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
never shrinks tubes or drops streamlines on its own; it renders whatever
radius the object carries. So `prune()` is the tool to reach for when
you fabricate fat tubes from line-only data and want to make sure the
overlap was not introduced by you.

The selection is greedy and deterministic, preferring streamlines that
sit farthest from the already-kept tubes so the retained set spreads
across the bundle rather than clustering.

## Usage

``` r
prune(x, radius, overlap_margin = 1, ...)
```

## Arguments

- x:

  A
  [fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
  or
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
  to prune.

- radius:

  Positive number. The tube radius (world units) used both for the
  non-overlap clearance and for the hull-coverage test.

- overlap_margin:

  Numeric. Multiplier on the centre-to-centre clearance between kept
  tubes. The default `1` keeps tubes exactly at radius so they just
  touch; a value above `1` leaves a visible gap (and a value below `1`
  would let them interpenetrate, which is allowed but rarely wanted).

- ...:

  Reserved for future arguments.

## Value

An object of the same class as `x` holding the pruned subset of
streamlines. For a
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
the pruning is applied to every bundle independently, and empty bundles
are dropped from the returned set.

## See also

[`fatten()`](https://tractoverse.github.io/rtists/reference/fatten.md),
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md).
[`fatten()`](https://tractoverse.github.io/rtists/reference/fatten.md)
is the convenience wrapper that derives the radius for you and calls
this engine internally.

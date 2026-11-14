# Assign a visible tube radius to line-only streamlines

`fatten()` gives a
[fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html),
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html),
or
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html)
that carries no radius data a tube radius guaranteed to be visible to
the naked eye, and stores it back on the object as a per-streamline
`radius` key. Where
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
*reports* radius data the object already carries, and
[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)
thins a bundle down to a non-overlapping subset at a radius you choose,
over which
[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)
gives you full control as the tunable engine. `fatten()` is the
convenience wrapper that *picks* a radius for you and then reuses
[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)'s
selection logic internally for the dense case: afterwards a plain
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
call draws real 3D tubes. When you would rather pick the radius and the
clearance between tubes yourself, call
[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md)
directly instead.

The radius is chosen from the geometry of the streamlines themselves:

- **Sparse** streamlines (far apart relative to the visibility floor)
  keep all their fibres and get a constant radius equal to half the
  minimal distance between any two streamlines, so adjacent tubes just
  touch and nothing is hidden.

- **Dense** streamlines (packed closer than the floor) are pruned to a
  non-overlapping, hull-covering subset at the floor radius, preserving
  as many streamlines as can be shown without overlap at a visible size.

The visibility floor is the median distance between consecutive sampled
points of the streamlines (the sampling density); a tube is treated as
visible once its radius reaches that spacing. Override it with
`visibility`.

## Usage

``` r
fatten(x, visibility = NULL, ...)
```

## Arguments

- x:

  A
  [fiber::streamline](https://tractoverse.github.io/fiber/reference/streamline.html),
  [fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html),
  or
  [fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html).

- visibility:

  Numeric. The smallest tube radius considered visible to the naked eye.
  `NULL` (default) derives it from the streamlines' sampling density
  (the median intra-streamline step); a positive number overrides the
  floor.

- ...:

  Reserved for future arguments.

## Value

An object of the same class as `x` in which every streamline carries a
per-streamline `radius` in its `@streamline_data`, so a subsequent
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)
call renders real 3D tubes. For a dense
[fiber::bundle](https://tractoverse.github.io/fiber/reference/bundle.html)
or
[fiber::bundle_set](https://tractoverse.github.io/fiber/reference/bundle_set.html),
the returned object holds the pruned (non-overlapping) subset of
streamlines.

## See also

[`prune()`](https://tractoverse.github.io/rtists/reference/prune.md),
[`plot3d()`](https://tractoverse.github.io/rtists/reference/plot3d.md)

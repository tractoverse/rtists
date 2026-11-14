# Launch an interactive rtists Shiny demo

Starts one of the Shiny demo apps shipped in the rtists source tree
under `demo/<name>/` using
[`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html). The
demos exercise the three.js r186 htmlwidget in a live app and double as
an end-to-end check of the asynchronous ESM loader.

## Usage

``` r
runDemo(name = "line2", ...)
```

## Arguments

- name:

  Character. Name of a demo app; must match a subfolder of `demo/` in
  the repository root. Defaults to `"line2"`.

- ...:

  Additional arguments passed on to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html) (e.g.
  `port`, `host`, `launch.browser`).

## Value

`TRUE` invisibly once the app session ends (the app itself blocks until
closed).

## Details

Because `demo/` is excluded from the built package (see
`.Rbuildignore`), this helper is only available from a **source
checkout** of rtists — i.e. after `devtools::load_all()` or when the
working directory is inside the repository. There is currently one demo:

- `"line2"`: a synthetic bundle rendered both in the default `Line2`
  mode and as variable-radius tubes (radial-displacement path).

## Examples

``` r
if (FALSE) { # \dontrun{
# from the repository root or after devtools::load_all()
rtists::runDemo("line2")
} # }
```

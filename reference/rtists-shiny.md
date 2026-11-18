# Shiny output / render functions for the three.js backend.

Shiny output / render functions for the three.js backend.

## Usage

``` r
rtistsOutput(outputId, width = "100%", height = "480px")

renderRtists(expr, env = parent.frame(), quoted = FALSE)
```

## Arguments

- outputId:

  Output variable to read the widget from.

- width, height:

  Must be a valid CSS unit (like `"100%"`, `"400px"`, `"auto"`) or a
  number, which will be coerced to a string and have `"px"` appended.

- expr:

  An expression that generates an `rtists` widget.

- env:

  The environment in which to evaluate `expr`.

- quoted:

  Is `expr` a quoted expression?

## Value

An output or render function that enables use of the widget within Shiny
applications.

## Examples

``` r
if (interactive()) {
  library(shiny)
  library(fiber)

  sl <- streamline(cbind(
    X = seq_len(200) * 0.1,
    Y = 0.5 * sin(seq_len(200) / 200 * 4 * pi),
    Z = 0.5 * cos(seq_len(200) / 200 * 4 * pi)
  ))
  ui <- fluidPage(rtistsOutput("viewer"))
  server <- function(input, output, session) {
    output$viewer <- renderRtists(plot3d(sl))
  }
  shinyApp(ui, server)
}
```

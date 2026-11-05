# rtists three.js r186 (Line2) Shiny demo.
#
# Launched from R via  rtists::runExample("line2")  (which calls shiny::runApp
# on this directory). Demonstrates the three.js r186 htmlwidget inside a live
# Shiny app, exercising both render paths:
#   * "line2" - the default backend (fast constant-width Line2 lines)
#   * "tube"  - variable per-point radius (TubeGeometry + radial displacement)
#
# It also doubles as the end-to-end check for the async ESM loader: the widget
# is registered when the dynamically-imported ESM module runs, so if the outputs
# render, registration timing holds in a live app.
library(shiny)
library(rtists)
library(fiber)

# A small synthetic bundle with per-point FA metadata.
make_bundle <- function() {
  helix <- function(n, phase, r = 4, amp = 10) {
    t <- seq(0, 1, length.out = n)
    m <- cbind(cos(2 * pi * 3 * t + phase) * r,
               sin(2 * pi * 3 * t + phase) * r,
               (t - 0.5) * amp)
    colnames(m) <- c("X", "Y", "Z")
    m
  }
  sls <- lapply(seq(0, 6, by = 2), function(ph) {
    streamline(
      points     = helix(30, ph),
      point_data = list(FA = runif(30, 0.2, 0.9))
    )
  })
  bundle(sls)
}

bun <- make_bundle()

ui <- fluidPage(
  tags$h3("rtists three.js r186 end-to-end (Shiny)"),
  fluidRow(
    column(6, rtistsOutput("line2", height = "400px")),
    column(6, rtistsOutput("tube",  height = "400px"))
  )
)

server <- function(input, output, session) {
  output$line2 <- renderRtists({
    plot3d(bun, color = "FA")                 # default threejs -> line2 mode
  })

  output$tube <- renderRtists({
    # A per-point radius vector -> tube mode (radial displacement path).
    r <- unlist(lapply(seq(0, 6, by = 2), function(ph) {
      0.2 + 1.2 * sin(seq(0, pi, length.out = 30))
    }))
    plot3d(bun, radius = r, opacity = 0.85)
  })
}

shinyApp(ui, server)

## plot_theme_helper.R
## Shared visual style for all exploratory plots (base R and ggplot2).

set_base_plot_style <- function() {
  par(
    family = "sans",
    bty = "l",
    las = 1,
    cex.axis = 0.9,
    cex.lab = 0.95,
    cex.main = 1
  )
}

theme_total_peace <- function() {
  if (!requireNamespace("ggplot2", quietly = TRUE)) return(ggplot2::theme_minimal())
  ggplot2::theme_minimal(base_family = "sans") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", hjust = 0, size = 11),
      plot.subtitle = ggplot2::element_text(size = 9, hjust = 0),
      plot.caption = ggplot2::element_text(size = 8, hjust = 0),
      axis.title = ggplot2::element_text(size = 9),
      axis.text = ggplot2::element_text(size = 8),
      legend.title = ggplot2::element_text(size = 9),
      legend.text = ggplot2::element_text(size = 8)
    )
}


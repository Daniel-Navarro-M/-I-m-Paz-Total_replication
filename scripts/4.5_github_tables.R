options(stringsAsFactors = FALSE)

library(tinytex)
library(pdftools)
library(magick)

dir.create("output/tables/git_tables", recursive = TRUE, showWarnings = FALSE)

tables <- data.frame(
  tex = c(
    "output/tables/Robustness_Check_twfe.tex",
    "output/tables/Robustness_Check_twfe_clustered_error.tex",
    "output/tables/results_pooled_ols_latex.tex",
    "output/tables/results_case_fe_latex.tex",
    "output/tables/results_twfe_latex.tex",
    "output/tables/violence_ols_results_latex.tex",
    "output/tables/violence_case_fe_results_latex.tex",
    "output/tables/violence_twfe_results_latex.tex"
  ),
  png = c(
    "output/tables/git_tables/table_a1_robustness_twfe.png",
    "output/tables/git_tables/table_a2_robustness_twfe_clustered.png",
    "output/tables/git_tables/table_a3_results_pooled_ols.png",
    "output/tables/git_tables/table_a4_results_case_fe.png",
    "output/tables/git_tables/table_a5_results_twfe.png",
    "output/tables/git_tables/table_a6_violence_ols.png",
    "output/tables/git_tables/table_a7_violence_case_fe.png",
    "output/tables/git_tables/table_a8_violence_twfe.png"
  ),
  stringsAsFactors = FALSE
)

render_table_png <- function(tex_file, png_file) {
  tex_abs <- normalizePath(tex_file, winslash = "/", mustWork = TRUE)
  workdir <- tempdir()
  wrapper <- file.path(workdir, "table_wrapper.tex")

  wrapper_text <- c(
    "\\documentclass{article}",
    "\\usepackage[margin=0.3in]{geometry}",
    "\\usepackage{booktabs}",
    "\\usepackage{makecell}",
    "\\usepackage{amsmath}",
    "\\pagestyle{empty}",
    "\\begin{document}",
    sprintf("\\input{%s}", tex_abs),
    "\\end{document}"
  )

  writeLines(wrapper_text, wrapper)
  tinytex::latexmk(wrapper, engine = "pdflatex")

  pdf_file <- sub("\\.tex$", ".pdf", wrapper)
  converted <- pdftools::pdf_convert(pdf = pdf_file, format = "png", dpi = 240)
  file.copy(converted[1], png_file, overwrite = TRUE)

  img <- magick::image_read(png_file)
  img <- magick::image_trim(img)
  img <- magick::image_border(img, color = "white", geometry = "10x10")
  magick::image_write(img, path = png_file, format = "png")
}

for (i in seq_len(nrow(tables))) {
  render_table_png(tables$tex[i], tables$png[i])
}

cat("\n=== 4.5_github_tables.R complete ===\n")
cat("Table PNGs saved to: output/tables/git_tables/\n")
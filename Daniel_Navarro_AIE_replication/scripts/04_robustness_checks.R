# 04_robustness.R
# Minimal robustness checks for the simple monthly case panel.

options(stringsAsFactors = FALSE)

if (!requireNamespace("fixest", quietly = TRUE)) stop("Install fixest: install.packages('fixest')")
if (!requireNamespace("writexl", quietly = TRUE)) stop("Install writexl: install.packages('writexl')")
library(fixest)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables/latex", recursive = TRUE, showWarnings = FALSE)

latex_escape <- function(x) {
  x <- as.character(x)
  x <- gsub("\\\\", "\\\\textbackslash{}", x)
  x <- gsub("([_%#&$])", "\\\\\\1", x, perl = TRUE)
  x
}

write_latex_table <- function(df, path, caption, label) {
  fmt <- df
  for (j in seq_along(fmt)) {
    if (is.numeric(fmt[[j]])) fmt[[j]] <- ifelse(is.na(fmt[[j]]), "", format(round(fmt[[j]], 3), nsmall = 3, trim = TRUE))
    fmt[[j]] <- latex_escape(fmt[[j]])
  }
  header <- paste(names(fmt), collapse = " & ")
  rows <- apply(fmt, 1, function(r) paste(r, collapse = " & "))
  body <- paste0(rows, " \\\\")
  aligns <- paste(c("l", rep("c", ncol(fmt) - 1)), collapse = " ")
  lines <- c(
    "\\begin{table}[ht]",
    "\\centering",
    paste0("\\caption{", latex_escape(caption), "}"),
    paste0("\\label{", label, "}"),
    paste0("\\begin{tabular}{", aligns, "}"),
    "\\hline",
    paste0(header, " \\\\"),
    "\\hline",
    body,
    "\\hline",
    "\\end{tabular}",
    "\\end{table}"
  )
  writeLines(lines, path)
}

panel <- readRDS("output/panel_monthly.rds")
panel$month_start <- as.Date(paste0(panel$month_id, "-01"))

shift_months <- function(d, n_back = 6) {
  y <- as.integer(format(d, "%Y"))
  m <- as.integer(format(d, "%m"))
  total <- y * 12 + m - 1 - n_back
  new_y <- total %/% 12
  new_m <- total %% 12 + 1
  as.Date(sprintf("%04d-%02d-01", new_y, new_m))
}

# -----------------------------------------------------------------------------
# 1. Placebo treatment: 6 months before the observed start
# -----------------------------------------------------------------------------

onset <- aggregate(month_start ~ case_id, data = panel[panel$treatment == 1, ], FUN = min)
onset$placebo_start <- shift_months(onset$month_start, 6)

panel$placebo_treatment <- 0L
for (i in seq_len(nrow(onset))) {
  idx <- panel$case_id == onset$case_id[i]
  panel$placebo_treatment[idx &
                            panel$month_start >= onset$placebo_start[i] &
                            panel$month_start < onset$month_start[i]] <- 1L
}

placebo_model <- feols(total_events ~ placebo_treatment + clash_dummy | case_id + month_id, data = panel)

# -----------------------------------------------------------------------------
# 2. Leave-one-case-out TWFE
# -----------------------------------------------------------------------------

case_ids <- unique(as.character(panel$case_id))
loo_df <- do.call(rbind, lapply(case_ids, function(drop_case) {
  sub <- panel[panel$case_id != drop_case, ]
  mod <- feols(total_events ~ treatment + clash_dummy | case_id + month_id, data = sub)
  data.frame(
    dropped_case = drop_case,
    estimate = unname(coef(mod)["treatment"]),
    std_error = unname(sqrt(diag(vcov(mod)))["treatment"]),
    stringsAsFactors = FALSE
  )
}))

# -----------------------------------------------------------------------------
# 3. Save outputs
# -----------------------------------------------------------------------------

placebo_df <- as.data.frame(summary(placebo_model)$coeftable)
placebo_df$term <- rownames(placebo_df)
rownames(placebo_df) <- NULL

writexl::write_xlsx(
  list(
    placebo = placebo_df,
    leave_one_out = loo_df
  ),
  "output/tables/robustness_results.xlsx"
)
write_latex_table(
  placebo_df,
  "output/tables/latex/robustness_placebo.tex",
  "Placebo treatment test.",
  "tab:robustness_placebo"
)
write_latex_table(
  loo_df,
  "output/tables/latex/robustness_leave_one_out.tex",
  "Leave-one-case-out treatment estimates.",
  "tab:robustness_loo"
)

cat("Robustness checks written to output/tables/robustness_results.xlsx.\n")

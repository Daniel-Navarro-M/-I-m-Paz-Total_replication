# 03_models.R
# Simple panel-data models following the course scripts:
#   OLS -> Case fixed effects -> TWFE -> TWFE + clash control

options(stringsAsFactors = FALSE)

if (!requireNamespace("fixest", quietly = TRUE)) stop("Install fixest: install.packages('fixest')")
if (!requireNamespace("texreg", quietly = TRUE)) stop("Install texreg: install.packages('texreg')")
if (!requireNamespace("writexl", quietly = TRUE)) stop("Install writexl: install.packages('writexl')")
if (!requireNamespace("modelsummary", quietly = TRUE)) stop("Install modelsummary: install.packages('modelsummary')")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2: install.packages('ggplot2')")
if (!requireNamespace("broom", quietly = TRUE)) stop("Install broom: install.packages('broom')")
if (!requireNamespace("knitr", quietly = TRUE)) stop("Install knitr: install.packages('knitr')")
if (!requireNamespace("readr", quietly = TRUE)) stop("Install readr: install.packages('readr')")
if (!requireNamespace("dplyr", quietly = TRUE)) stop("Install dplyr: install.packages('dplyr')")
if (!requireNamespace("tidyr", quietly = TRUE)) stop("Install tidyr: install.packages('tidyr')")

library(fixest)
library(texreg)
library(modelsummary)
library(ggplot2)
library(broom)
library(knitr)
library(readr)
library(dplyr)
library(tidyr)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Load panel
# -----------------------------------------------------------------------------

panel <- read_csv("data/Processed/panel_long.csv")

violence_types <- c(
  "political_violence",
  "civilian_targeting",
  "homicide",
  "terrorism",
  "extortion"
)
violence_labels <- c(
  political_violence = "Political violence",
  civilian_targeting = "Civilian targeting",
  homicide = "Homicide",
  terrorism = "Terrorism",
  extortion = "Extortion"
)

# Two-line column headers for LaTeX (narrower columns). Thesis preamble must include:
#   \usepackage{makecell}
violence_col_headers_twfe <- c(
  political_violence = "\\makecell{Political\\\\violence}",
  civilian_targeting = "\\makecell{Civilian\\\\targeting}",
  homicide = "Homicide",
  terrorism = "Terrorism",
  extortion = "Extortion"
)

# Multi-line LaTeX table notes (used in texreg custom.note): wrap in \\parbox so \\\\ is a line
# break inside the footnote cell (bare \\\\ would end the tabular row).
latex_note_pooled <- paste0(
  "\\parbox{\\linewidth}{",
  "Standard errors in parentheses.\\\\[0.35em] ",
  "\\textbf{Col.~(3):} Peace talks, active armed-group dispute, and treat.$\\times$dispute.",
  "}"
)
latex_note_case_fe <- paste0(
  "\\parbox{\\linewidth}{",
  "Standard errors in parentheses.\\\\[0.35em] ",
  "All columns include territorial-case fixed effects.\\\\[0.35em] ",
  "\\textbf{Col.~(3):} Adds peace talks $\\times$ active armed-group dispute.",
  "}"
)
latex_note_twfe <- paste0(
  "\\parbox{\\linewidth}{",
  "Standard errors in parentheses.\\\\[0.35em] ",
  "\\textbf{Cols.~(1)--(3):} Territorial-case and month fixed effects.\\\\[0.35em] ",
  "\\textbf{Col.~(4):} Case-specific peace talks and treat.$\\times$dispute.\\\\[0.35em] ",
  "Arauca/Tumaco interaction terms omitted when collinear; only Buenaventura treat.$\\times$dispute reported among interactions.",
  "}"
)
latex_note_violence_twfe <- paste0(
  "\\parbox{\\linewidth}{",
  "Standard errors in parentheses.\\\\[0.35em] ",
  "Each column is a separate violence outcome (monthly event counts).\\\\[0.35em] ",
  "All models include territorial-case and month fixed effects.",
  "}"
)
latex_note_supp <- paste0(
  "\\parbox{\\linewidth}{",
  "Standard errors in parentheses.\\\\[0.35em] ",
  "Both columns include territorial-case and month fixed effects.\\\\[0.35em] ",
  "\\textbf{Col.~(2):} Adds peace talks $\\times$ active armed-group dispute.",
  "}"
)

clean_tex_table_text <- function(lines) {
  lines <- gsub("case\\_id", "case id", lines, fixed = TRUE)
  lines <- gsub("month\\_id", "month id", lines, fixed = TRUE)
  lines
}

# Case-specific treatment_dummy indicators for heterogeneous TWFE effects.
panel$tr_buenaventura <- ifelse(panel$case_id == "buenaventura", panel$treatment_dummy, 0)
panel$tr_arauca <- ifelse(panel$case_id == "arauca", panel$treatment_dummy, 0)
panel$tr_tumaco <- ifelse(panel$case_id == "tumaco", panel$treatment_dummy, 0)

# 2. Main models ----

# (1) Pooled OLS
m1 <- lm(count ~ treatment_dummy, data = panel)
screenreg(
  list(m1),
  custom.model.names = c("OLS Without control"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)

m1_1 <- lm(count ~ treatment_dummy + clash_dummy, data = panel)
screenreg(
  list(m1_1),
  custom.model.names = c("OLS Clash Control"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)

# Pooled OLS: clash control + interaction (explicit RHS)
m1_2 <- lm(count ~ treatment_dummy + clash_dummy + treatment_dummy * clash_dummy, data = panel)


# (2) Case fixed effects
m2 <- feols(count ~ treatment_dummy | case_id, data = panel)

screenreg(
  list(m2),
  custom.model.names = c("FE OLS Cluster by Region"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)

m2_1 <- feols(count ~ treatment_dummy + clash_dummy | case_id, data = panel)

# Case FE with treatment_dummy + clash + interaction
m2_2 <- feols(count ~ treatment_dummy + clash_dummy + treatment_dummy * clash_dummy | case_id, data = panel)

screenreg(
  list(m2_2),
  custom.model.names = c("FE OLS Cluster by Region controll Clash Dummy"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)

# (3) Two-way fixed effects: case + month
m3 <- feols(count ~ treatment_dummy | case_id + month_id, data = panel)
# (4) TWFE + armed-group dispute control
m4 <- feols(count ~ treatment_dummy + clash_dummy | case_id + month_id, data = panel)

# (4b) TWFE: clash control + interaction (explicit RHS, same as course spec)
m4_int <- feols(
  count ~ treatment_dummy + clash_dummy + treatment_dummy * clash_dummy | case_id + month_id,
  data = panel
)

# (5) Heterogeneous TWFE: case-specific treatment_dummy + clash control
m5 <- feols(
  count ~ tr_buenaventura + tr_arauca + tr_tumaco + clash_dummy | case_id + month_id,
  data = panel
)

# (5b) Heterogeneous TWFE: case-specific treatment_dummy + clash + interaction each case (explicit RHS)
m5_int <- feols(
  count ~ tr_buenaventura + tr_arauca + tr_tumaco + clash_dummy +
    tr_buenaventura * clash_dummy + tr_arauca * clash_dummy + tr_tumaco * clash_dummy |
    case_id + month_id,
  data = panel
)

screenreg(
  list(m5_int),
  custom.model.names = c("FE OLS Cluster by Region controll Clash Dummy"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)


cat("\n=== Fixed-effects models by violence type ===\n")
violence_model_results <- list()
violence_model_results_fe <- list()
violence_model_results_ols <- list()
violence_model_results_twfe <- list()
violence_model_results_twfe_main <- list()
violence_model_results_twfe_interaction <- list()

# Models with each type of violence 

# OLS
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  panel_sub <- panel |> dplyr::filter(violence_type == v)
  model_formula <- count ~ treatment_dummy + clash_dummy
  mod <- lm(model_formula, data = panel_sub)
  violence_model_results[[v]] <- mod
  violence_model_results_ols[[v]] <- mod
  cat(
    screenreg(
      list(mod),
      custom.model.names = c(paste("General OLS + Clash:", model_name)),
      custom.coef.map = list(
        "treatment_dummy" = "Peace talks active",
        "clash_dummy" = "Active armed-group dispute"
      ),
      caption = paste("Effect of peace talks on", tolower(model_name)),
      caption.above = TRUE,
      include.ci = FALSE,
      stars = c(0.01, 0.05, 0.10),
      custom.note = "Standard errors in parentheses."
    )
  )
}

# FE OLS
 
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  panel_sub <- panel |> dplyr::filter(violence_type == v)
  model_formula <- count ~ treatment_dummy + clash_dummy | case_id
  mod <- feols(model_formula, data = panel_sub)
  violence_model_results[[v]] <- mod
  violence_model_results_fe[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("Case FE + Clash:", model_name)),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}


# TWFE by outcome: common treatment_dummy effect + clash control
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  panel_sub <- panel |> dplyr::filter(violence_type == v)
  model_formula <- count ~ treatment_dummy + clash_dummy | case_id + month_id
  mod <- feols(model_formula, data = panel_sub)
  violence_model_results[[v]] <- mod
  violence_model_results_twfe_main[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("TWFE + Clash:", model_name)),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}

# TWFE with clash control + interaction (same RHS structure as m4_int)
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  panel_sub <- panel |> dplyr::filter(violence_type == v)
  model_formula <- count ~ treatment_dummy + clash_dummy + treatment_dummy * clash_dummy | case_id + month_id
  mod <- feols(model_formula, data = panel_sub)
  violence_model_results[[v]] <- mod
  violence_model_results_twfe_interaction[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("TWFE + clash + interaction:", model_name)),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment_dummy:clash_dummy" = "Peace talks × active dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}

# LaTeX tables for violence-type loops (one column per outcome).
fe_violence_latex <- capture.output(
  texreg(
    unname(violence_model_results_fe[violence_types]),
    custom.model.names = unname(violence_labels[violence_types]),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = "Case fixed-effects models by violence outcome (with clash control)",
    caption.above = TRUE,
    label = "tab:violence_case_fe",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = "Standard errors in parentheses."
  )
)
writeLines(clean_tex_table_text(fe_violence_latex), "output/tables/violence_case_fe_results_latex.tex")

ols_violence_latex <- capture.output(
  texreg(
    unname(violence_model_results_ols[violence_types]),
    custom.model.names = unname(violence_labels[violence_types]),
    custom.coef.map = list(
      "(Intercept)" = "Constant",
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = "Pooled OLS models by violence outcome (with clash control)",
    caption.above = TRUE,
    label = "tab:violence_ols",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = "Standard errors in parentheses."
  )
)
writeLines(clean_tex_table_text(ols_violence_latex), "output/tables/violence_ols_results_latex.tex")

twfe_violence_latex <- capture.output(
  texreg(
    unname(violence_model_results_twfe_main[violence_types]),
    custom.model.names = unname(violence_col_headers_twfe[violence_types]),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = "TWFE models by violence outcome (with clash control)",
    caption.above = TRUE,
    label = "tab:violence_twfe",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = "Standard errors in parentheses. Each column is a separate violence outcome (monthly event counts). All models include territorial-case and month fixed effects."
  )
)
writeLines(clean_tex_table_text(twfe_violence_latex), "output/tables/violence_twfe_results_latex.tex")

twfe_interaction_violence_latex <- capture.output(
  texreg(
    unname(violence_model_results_twfe_interaction[violence_types]),
    custom.model.names = unname(violence_col_headers_twfe[violence_types]),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment_dummy:clash_dummy" = "Peace talks × active dispute"
    ),
    caption = "TWFE models by violence outcome (peace talks, active dispute, and interaction)",
    caption.above = TRUE,
    label = "tab:violence_twfe_interaction",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = latex_note_violence_twfe
  )
)
writeLines(clean_tex_table_text(twfe_interaction_violence_latex), "output/tables/violence_twfe_interaction_results_latex.tex")

coef_map <- list(
  "(Intercept)" = "Constant",
  "treatment_dummy" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute",
  "treatment_dummy:clash_dummy" = "Peace talks × active dispute",
  "tr_buenaventura" = "Peace talks (Buenaventura)",
  "tr_arauca" = "Peace talks (Arauca)",
  "tr_tumaco" = "Peace talks (Tumaco)",
  "tr_buenaventura:clash_dummy" = "Peace talks × dispute (Buenaventura)",
  "tr_arauca:clash_dummy" = "Peace talks × dispute (Arauca)",
  "tr_tumaco:clash_dummy" = "Peace talks × dispute (Tumaco)"
)

# Short two-line headers for regression tables (use with \\usepackage{makecell}).
hdr_col_pooled <- c(
  "\\makecell{(1) Pooled\\\\treat. only}",
  "\\makecell{(2) + active\\\\dispute}",
  "\\makecell{(3) + treat.$\\times$\\\\dispute}"
)
hdr_col_case_fe <- c(
  "\\makecell{(1) Case FE\\\\treat. only}",
  "\\makecell{(2) + active\\\\dispute}",
  "\\makecell{(3) + treat.$\\times$\\\\dispute}"
)
hdr_col_twfe <- c(
  "\\makecell{(1) TWFE\\\\treat. only}",
  "\\makecell{(2) + active\\\\dispute}",
  "\\makecell{(3) + treat.$\\times$\\\\dispute}",
  "\\makecell{(4) By case\\\\+ interact.}"
)

# -----------------------------------------------------------------------------
# 3. Main results: four separate LaTeX tables (pooled OLS, case FE, TWFE, legacy copy)
# -----------------------------------------------------------------------------

screenreg(
  list(m1, m1_1, m1_2),
  custom.model.names = hdr_col_pooled,
  custom.coef.map = coef_map,
  caption = "Pooled OLS: aggregate monthly violence",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = "SE in parentheses. Col. 3: peace talks, dispute, interaction."
)

screenreg(
  list(m2, m2_1, m2_2),
  custom.model.names = hdr_col_case_fe,
  custom.coef.map = coef_map,
  caption = "Case fixed effects: aggregate monthly violence",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = "SE in parentheses. All cols: case FE. Col. 3: adds talks x dispute."
)

screenreg(
  list(m3, m4, m4_int, m5_int),
  custom.model.names = hdr_col_twfe,
  custom.coef.map = coef_map,
  caption = "Two-way fixed effects: aggregate monthly violence",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = "SE in parentheses. Cols 1-3: TWFE. Col 4: by-case talks + interaction (some terms collinear)."
)

texreg_pooled <- capture.output(
  texreg(
    list(m1, m1_1, m1_2),
    custom.model.names = hdr_col_pooled,
    custom.coef.map = coef_map,
    caption = "Pooled OLS: effect of peace talks on aggregate monthly event counts",
    caption.above = TRUE,
    label = "tab:results_pooled_ols",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = latex_note_pooled
  )
)
writeLines(clean_tex_table_text(texreg_pooled), "output/tables/results_pooled_ols_latex.tex")

texreg_case_fe <- capture.output(
  texreg(
    list(m2, m2_1, m2_2),
    custom.model.names = hdr_col_case_fe,
    custom.coef.map = coef_map,
    caption = "Case fixed effects: effect of peace talks on aggregate monthly event counts",
    caption.above = TRUE,
    label = "tab:results_case_fe",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = latex_note_case_fe
  )
)
writeLines(clean_tex_table_text(texreg_case_fe), "output/tables/results_case_fe_latex.tex")

texreg_twfe <- capture.output(
  texreg(
    list(m3, m4, m4_int, m5_int),
    custom.model.names = hdr_col_twfe,
    custom.coef.map = coef_map,
    caption = "Two-way fixed effects: effect of peace talks on aggregate monthly event counts",
    caption.above = TRUE,
    label = "tab:results_twfe",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = latex_note_twfe
  )
)
writeLines(clean_tex_table_text(texreg_twfe), "output/tables/results_twfe_latex.tex")

# Backward compatibility: point main_results_latex at the TWFE block (most common cite)
texreg_out <- texreg_twfe
writeLines(clean_tex_table_text(texreg_out), "output/tables/main_results_latex.tex")
writeLines(clean_tex_table_text(texreg_out), "output/tables/main_results_unified_latex.tex")

supplementary_interaction_latex <- capture.output(
  texreg(
    list(m4, m4_int),
    custom.model.names = c("(1) TWFE + Clashes", "(2) TWFE + Clashes + Interaction"),
    custom.coef.map = list(
      "treatment_dummy" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment_dummy:clash_dummy" = "Peace talks x active dispute"
    ),
    caption = "Supplementary interaction model: peace talks and active armed-group dispute",
    caption.above = TRUE,
    label = "tab:twfe_interaction",
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    booktabs = TRUE,
    use.packages = FALSE,
    custom.note = latex_note_supp
  )
)
writeLines(clean_tex_table_text(supplementary_interaction_latex), "output/tables/supplementary_interaction_results_latex.tex")

# -----------------------------------------------------------------------------
# 3b. Broom + knitr exports (simple LaTeX tables + coefficient plots)
# -----------------------------------------------------------------------------

star_code <- function(p) {
  ifelse(is.na(p), "",
    ifelse(p < 0.01, "***",
      ifelse(p < 0.05, "**",
        ifelse(p < 0.10, "*", "")
      )
    )
  )
}

build_broom_table <- function(models, model_names, coef_map, path, caption, label) {
  tidied <- dplyr::bind_rows(lapply(seq_along(models), function(i) {
    broom::tidy(models[[i]]) |>
      dplyr::mutate(model = model_names[i])
  }))

  coef_terms <- names(coef_map)
  tab <- tidied |>
    dplyr::filter(term %in% coef_terms) |>
    dplyr::mutate(
      term_label = unname(coef_map[term]),
      cell = sprintf("%.2f%s (%.2f)", estimate, star_code(p.value), std.error)
    ) |>
    dplyr::select(term_label, model, cell) |>
    dplyr::distinct() |>
    tidyr::pivot_wider(names_from = model, values_from = cell) |>
    dplyr::mutate(term_label = factor(term_label, levels = unname(coef_map))) |>
    dplyr::arrange(term_label) |>
    dplyr::mutate(term_label = as.character(term_label))

  latex <- knitr::kable(
    tab,
    format = "latex",
    booktabs = TRUE,
    caption = caption,
    label = label,
    escape = FALSE,
    col.names = c("", model_names)
  )

  writeLines(clean_tex_table_text(latex), path)
}

plot_broom_models <- function(models, model_names, coef_map, plot_path, title) {
  coef_terms <- names(coef_map)
  pdat <- dplyr::bind_rows(lapply(seq_along(models), function(i) {
    broom::tidy(models[[i]], conf.int = TRUE) |>
      dplyr::mutate(model = model_names[i])
  })) |>
    dplyr::filter(term %in% coef_terms) |>
    dplyr::mutate(
      estimate = as.numeric(estimate),
      conf.low = as.numeric(conf.low),
      conf.high = as.numeric(conf.high),
      term_label = as.character(unname(coef_map[term])),
      significant = ifelse(p.value < 0.05, "yes", "no")
    ) |>
    dplyr::filter(is.finite(estimate), is.finite(conf.low), is.finite(conf.high))

  p <- ggplot(
    pdat,
    aes(x = estimate, y = term_label, color = model)
  ) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "gray60") +
    geom_pointrange(
      aes(xmin = conf.low, xmax = conf.high),
      position = position_dodge(width = 0.5)
    ) +
    labs(title = title, x = "Estimate", y = NULL) +
    theme_bw()

  ggsave(plot_path, p, width = 8, height = 5, dpi = 150)
}

coef_map_pooled <- list(
  "(Intercept)" = "Constant",
  "treatment_dummy" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute",
  "treatment_dummy:clash_dummy" = "Peace talks × active dispute"
)
coef_map_main <- list(
  "treatment_dummy" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute",
  "treatment_dummy:clash_dummy" = "Peace talks × active dispute",
  "tr_buenaventura" = "Peace talks (Buenaventura)",
  "tr_arauca" = "Peace talks (Arauca)",
  "tr_tumaco" = "Peace talks (Tumaco)",
  "tr_buenaventura:clash_dummy" = "Peace talks × dispute (Buenaventura)",
  "tr_arauca:clash_dummy" = "Peace talks × dispute (Arauca)",
  "tr_tumaco:clash_dummy" = "Peace talks × dispute (Tumaco)"
)
coef_map_violence <- list(
  "treatment_dummy" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute"
)
coef_map_violence_int <- list(
  "treatment_dummy" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute",
  "treatment_dummy:clash_dummy" = "Peace talks × active dispute"
)

build_broom_table(
  models = list(m1, m1_1, m1_2),
  model_names = c("(1) Pooled treat only", "(2) + clash", "(3) + clash × treat"),
  coef_map = coef_map_pooled,
  path = "output/tables/results_pooled_ols_latex.tex",
  caption = "Pooled OLS: effect of peace talks on aggregate monthly event counts",
  label = "results_pooled_ols"
)
plot_broom_models(
  models = list(m1, m1_1, m1_2),
  model_names = c("Pooled 1", "Pooled 2", "Pooled 3"),
  coef_map = coef_map_pooled,
  plot_path = "output/figures/coefplot_pooled.png",
  title = "Pooled OLS coefficients"
)

build_broom_table(
  models = list(m2, m2_1, m2_2),
  model_names = c("(1) Case FE treat only", "(2) + clash", "(3) + clash × treat"),
  coef_map = coef_map_main,
  path = "output/tables/results_case_fe_latex.tex",
  caption = "Case fixed effects: effect of peace talks on aggregate monthly event counts",
  label = "results_case_fe"
)
plot_broom_models(
  models = list(m2, m2_1, m2_2),
  model_names = c("Case FE 1", "Case FE 2", "Case FE 3"),
  coef_map = coef_map_main,
  plot_path = "output/figures/coefplot_case_fe.png",
  title = "Case FE coefficients"
)

build_broom_table(
  models = list(m3, m4, m4_int, m5_int),
  model_names = c("(1) TWFE treat only", "(2) + clash", "(3) + clash × treat", "(4) By case + interact"),
  coef_map = coef_map_main,
  path = "output/tables/results_twfe_latex.tex",
  caption = "Two-way fixed effects: effect of peace talks on aggregate monthly event counts",
  label = "results_twfe"
)
plot_broom_models(
  models = list(m3, m4, m4_int, m5_int),
  model_names = c("TWFE 1", "TWFE 2", "TWFE 3", "TWFE 4"),
  coef_map = coef_map_main,
  plot_path = "output/figures/coefplot_twfe.png",
  title = "TWFE coefficients"
)

build_broom_table(
  models = unname(violence_model_results_twfe_main[violence_types]),
  model_names = unname(violence_labels[violence_types]),
  coef_map = coef_map_violence,
  path = "output/tables/violence_twfe_results_latex.tex",
  caption = "TWFE models by violence outcome (with clash control)",
  label = "violence_twfe"
)
plot_broom_models(
  models = unname(violence_model_results_twfe_main[violence_types]),
  model_names = unname(violence_labels[violence_types]),
  coef_map = coef_map_violence,
  plot_path = "output/figures/coefplot_violence_twfe.png",
  title = "TWFE by outcome (no interaction)"
)

build_broom_table(
  models = unname(violence_model_results_twfe_interaction[violence_types]),
  model_names = unname(violence_labels[violence_types]),
  coef_map = coef_map_violence_int,
  path = "output/tables/violence_twfe_interaction_results_latex.tex",
  caption = "TWFE models by violence outcome (peace talks, active dispute, and interaction)",
  label = "violence_twfe_interaction"
)
plot_broom_models(
  models = unname(violence_model_results_twfe_interaction[violence_types]),
  model_names = unname(violence_labels[violence_types]),
  coef_map = coef_map_violence_int,
  plot_path = "output/figures/coefplot_violence_twfe_interaction.png",
  title = "TWFE by outcome (with interaction)"
)

# Keep compatibility copies used in thesis text
file.copy("output/tables/results_twfe_latex.tex", "output/tables/main_results_latex.tex", overwrite = TRUE)
file.copy("output/tables/results_twfe_latex.tex", "output/tables/main_results_unified_latex.tex", overwrite = TRUE)

# -----------------------------------------------------------------------------
# 4. Coefficient plot
# -----------------------------------------------------------------------------

p_coef <- modelplot(
  list(
    "OLS" = m1,
    "Case FE" = m2,
    "TWFE" = m3,
    "TWFE + Clashes" = m4
  ),
  coef_map = c("treatment_dummy" = "Peace talks active")
) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  labs(
    title = "treatment_dummy coefficient across model specifications",
    x = "Estimated effect on monthly total events",
    y = "Model"
  ) +
  theme_bw()

print(p_coef)
ggsave("output/figures/coefficient_plot.png", p_coef, width = 8, height = 5, dpi = 150)

het_ct <- as.data.frame(summary(m5)$coeftable)
het_ct$term <- rownames(het_ct)
rownames(het_ct) <- NULL
names(het_ct)[1:4] <- c("estimate", "std_error", "statistic", "p_value")
het_ct$case_label <- c(
  "tr_buenaventura" = "Buenaventura",
  "tr_arauca" = "Arauca Department",
  "tr_tumaco" = "Tumaco Region"
)[het_ct$term]
het_ct <- het_ct[!is.na(het_ct$case_label), ]
het_ct$conf_low <- het_ct$estimate - 1.96 * het_ct$std_error
het_ct$conf_high <- het_ct$estimate + 1.96 * het_ct$std_error

p_case_coef <- ggplot(het_ct, aes(x = estimate, y = case_label)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_errorbar(aes(xmin = conf_low, xmax = conf_high), width = 0.15, color = "#2C3E50", orientation = "y") +
  geom_point(size = 2.8, color = "#C0392B") +
  labs(
    title = "Case-specific treatment_dummy coefficients from heterogeneous TWFE",
    x = "Estimated effect on monthly total events",
    y = NULL
  ) +
  theme_bw()

print(p_case_coef)
ggsave("output/figures/coefficient_plot_by_case.png", p_case_coef, width = 8, height = 5, dpi = 150)

# -----------------------------------------------------------------------------
# 5. Save coefficient tables to Excel
# -----------------------------------------------------------------------------

to_df <- function(mod, model_name) {
  ct <- summary(mod)$coeftable
  if (inherits(mod, "lm")) ct <- summary(mod)$coefficients
  df <- as.data.frame(ct)
  df$term <- rownames(ct)
  df$model <- model_name
  rownames(df) <- NULL
  df[, c("model", "term", setdiff(names(df), c("model", "term")))]
}

writexl::write_xlsx(
  list(
    OLS = to_df(m1, "OLS"),
    OLS_Clash = to_df(m1_1, "Pooled OLS + clash"),
    OLS_Clash_Interaction = to_df(m1_2, "Pooled OLS + clash + interaction"),
    Case_FE = to_df(m2, "Case FE"),
    Case_FE_Clash = to_df(m2_1, "Case FE + clash"),
    Case_FE_Clash_Interaction = to_df(m2_2, "Case FE + clash + interaction"),
    TWFE = to_df(m3, "TWFE"),
    TWFE_Clashes = to_df(m4, "TWFE + Clashes"),
    TWFE_Clashes_Interaction = to_df(m4_int, "TWFE + Clashes + Interaction"),
    TWFE_By_Case = to_df(m5, "TWFE by Case"),
    TWFE_By_Case_Interaction = to_df(m5_int, "TWFE by Case + clash + interaction"),
    Political_Violence_FE = to_df(violence_model_results_fe[["political_violence"]], "Case FE + Clash: Political violence"),
    Civilian_Targeting_FE = to_df(violence_model_results_fe[["civilian_targeting"]], "Case FE + Clash: Civilian targeting"),
    Homicides_FE = to_df(violence_model_results_fe[["homicide"]], "Case FE + Clash: Homicides"),
    Terrorism_FE = to_df(violence_model_results_fe[["terrorism"]], "Case FE + Clash: Terrorism"),
    Extortion_FE = to_df(violence_model_results_fe[["extortion"]], "Case FE + Clash: Extortion"),
    Political_Violence_OLS = to_df(violence_model_results_ols[["political_violence"]], "General OLS + Clash: Political violence"),
    Civilian_Targeting_OLS = to_df(violence_model_results_ols[["civilian_targeting"]], "General OLS + Clash: Civilian targeting"),
    Homicides_OLS = to_df(violence_model_results_ols[["homicide"]], "General OLS + Clash: Homicides"),
    Terrorism_OLS = to_df(violence_model_results_ols[["terrorism"]], "General OLS + Clash: Terrorism"),
    Extortion_OLS = to_df(violence_model_results_ols[["extortion"]], "General OLS + Clash: Extortion"),
    Political_Violence_TWFE = to_df(violence_model_results_twfe_main[["political_violence"]], "TWFE + Clash: Political violence"),
    Civilian_Targeting_TWFE = to_df(violence_model_results_twfe_main[["civilian_targeting"]], "TWFE + Clash: Civilian targeting"),
    Homicides_TWFE = to_df(violence_model_results_twfe_main[["homicide"]], "TWFE + Clash: Homicides"),
    Terrorism_TWFE = to_df(violence_model_results_twfe_main[["terrorism"]], "TWFE + Clash: Terrorism"),
    Extortion_TWFE = to_df(violence_model_results_twfe_main[["extortion"]], "TWFE + Clash: Extortion"),
    Political_Violence_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["political_violence"]], "TWFE + Clash + Interaction: Political violence"),
    Civilian_Targeting_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["civilian_targeting"]], "TWFE + Clash + Interaction: Civilian targeting"),
    Homicides_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["homicide"]], "TWFE + Clash + Interaction: Homicides"),
    Terrorism_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["terrorism"]], "TWFE + Clash + Interaction: Terrorism"),
    Extortion_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["extortion"]], "TWFE + Clash + Interaction: Extortion")
  ),
  "output/tables/model_results.xlsx"
)

cat("\n=== 03_models.R complete ===\n")
cat("Saved: output/tables/model_results.xlsx\n")
cat("Saved: output/tables/results_pooled_ols_latex.tex\n")
cat("Saved: output/tables/results_case_fe_latex.tex\n")
cat("Saved: output/tables/results_twfe_latex.tex\n")
cat("Saved: output/tables/main_results_latex.tex (copy of TWFE table)\n")
cat("Saved: output/tables/main_results_unified_latex.tex (copy of TWFE table)\n")
cat("Saved: output/tables/supplementary_interaction_results_latex.tex\n")
cat("Saved: output/tables/violence_case_fe_results_latex.tex\n")
cat("Saved: output/tables/violence_ols_results_latex.tex\n")
cat("Saved: output/tables/violence_twfe_results_latex.tex\n")
cat("Saved: output/tables/violence_twfe_interaction_results_latex.tex\n")
cat("Saved: output/figures/coefficient_plot.png\n")
cat("Saved: output/figures/coefficient_plot_by_case.png\n")

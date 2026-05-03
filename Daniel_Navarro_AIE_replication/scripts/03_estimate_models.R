# 03_models.R
# Simple panel-data models following the course scripts:
#   OLS -> Case fixed effects -> TWFE -> TWFE + clash control

options(stringsAsFactors = FALSE)

if (!requireNamespace("fixest", quietly = TRUE)) stop("Install fixest: install.packages('fixest')")
if (!requireNamespace("texreg", quietly = TRUE)) stop("Install texreg: install.packages('texreg')")
if (!requireNamespace("writexl", quietly = TRUE)) stop("Install writexl: install.packages('writexl')")
if (!requireNamespace("modelsummary", quietly = TRUE)) stop("Install modelsummary: install.packages('modelsummary')")
if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2: install.packages('ggplot2')")

library(fixest)
library(texreg)
library(modelsummary)
library(ggplot2)

dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Load panel
# -----------------------------------------------------------------------------

panel <- readRDS("output/panel_monthly.rds")
panel$month_start <- as.Date(paste0(panel$month_id, "-01"))
panel$case_id <- factor(panel$case_id, levels = c("buenaventura", "arauca", "tumaco"))

violence_types <- c(
  "political_violence",
  "civilian_targeting",
  "homicides",
  "terrorism",
  "extortion"
)
violence_labels <- c(
  political_violence = "Political violence",
  civilian_targeting = "Civilian targeting",
  homicides = "Homicides",
  terrorism = "Terrorism",
  extortion = "Extortion"
)

# Two-line column headers for LaTeX (narrower columns). Thesis preamble must include:
#   \usepackage{makecell}
violence_col_headers_twfe <- c(
  political_violence = "\\makecell{Political\\\\violence}",
  civilian_targeting = "\\makecell{Civilian\\\\targeting}",
  homicides = "Homicides",
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

# Case-specific treatment indicators for heterogeneous TWFE effects.
panel$tr_buenaventura <- ifelse(panel$case_id == "buenaventura", panel$treatment, 0)
panel$tr_arauca <- ifelse(panel$case_id == "arauca", panel$treatment, 0)
panel$tr_tumaco <- ifelse(panel$case_id == "tumaco", panel$treatment, 0)

cat("\n=== Simple TWFE analysis ===\n")
cat("Outcome   : total_events\n")
cat("Treatment : treatment\n")
cat("Control   : clash_dummy\n")
cat("Units     : study cases\n")
cat("Time      : month_id\n")
cat("Rows      :", nrow(panel), "\n")

# -----------------------------------------------------------------------------
# 2. Main models
# -----------------------------------------------------------------------------

# (1) Pooled OLS
m1 <- lm(total_events ~ treatment, data = panel)
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

m1_1 <- lm(total_events ~ treatment + clash_dummy, data = panel)
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
m1_2 <- lm(total_events ~ treatment + clash_dummy + treatment * clash_dummy, data = panel)



# (2) Case fixed effects
m2 <- feols(total_events ~ treatment | case_id, data = panel)

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

m2_1 <- feols(total_events ~ treatment + clash_dummy | case_id, data = panel)

# Case FE with treatment + clash + interaction
m2_2 <- feols(total_events ~ treatment + clash_dummy + treatment * clash_dummy | case_id, data = panel)

screenreg(
  list(m2_1),
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
m3 <- feols(total_events ~ treatment | case_id + month_id, data = panel)

# (4) TWFE + armed-group dispute control
m4 <- feols(total_events ~ treatment + clash_dummy | case_id + month_id, data = panel)

# (4b) TWFE: clash control + interaction (explicit RHS, same as course spec)
m4_int <- feols(
  total_events ~ treatment + clash_dummy + treatment * clash_dummy | case_id + month_id,
  data = panel
)

# (5) Heterogeneous TWFE: case-specific treatment + clash control
m5 <- feols(
  total_events ~ tr_buenaventura + tr_arauca + tr_tumaco + clash_dummy | case_id + month_id,
  data = panel
)

# (5b) Heterogeneous TWFE: case-specific treatment + clash + interaction each case (explicit RHS)
m5_int <- feols(
  total_events ~ tr_buenaventura + tr_arauca + tr_tumaco + clash_dummy +
    tr_buenaventura * clash_dummy + tr_arauca * clash_dummy + tr_tumaco * clash_dummy |
    case_id + month_id,
  data = panel
)

screenreg(
  list(m5),
  custom.model.names = c("FE OLS Cluster by Region controll Clash Dummy"),
  caption = "Effect of peace talks on monthly event counts",
  caption.above = TRUE,
  include.ci = FALSE,
  stars = c(0.01, 0.05, 0.10),
  custom.note = paste(
    "Standard errors in parentheses."
  )
)

cat("\nModels estimated: m1/m1_1/m1_2 pooled OLS; m2/m2_1/m2_2 case FE; m3/m4/m4_int/m5/m5_int TWFE.\n")
cat("Note: clash_dummy controls for months with active armed-group dispute in each case.\n")
cat("Note: m5 estimates separate treatment associations for Buenaventura, Arauca, and Tumaco (TWFE + clash).\n")
cat("Note: m5_int uses tr_* + clash_dummy + tr_* * clash_dummy for each case (heterogeneous TWFE).\n")
cat("Note: Interaction models use treatment + clash_dummy + treatment * clash_dummy (explicit clash + interaction).\n")

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
  model_formula <- as.formula(paste0(v, " ~ treatment + clash_dummy"))
  mod <- lm(model_formula, data = panel)
  violence_model_results[[v]] <- mod
  violence_model_results_ols[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("General OLS + Clash:", model_name)),
    custom.coef.map = list(
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}

# FE OLS
 
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  model_formula <- as.formula(paste0(v, " ~ treatment + clash_dummy | case_id"))
  mod <- feols(model_formula, data = panel)
  violence_model_results[[v]] <- mod
  violence_model_results_fe[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("Case FE + Clash:", model_name)),
    custom.coef.map = list(
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}


# TWFE by outcome: common treatment effect + clash control
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  model_formula <- as.formula(paste0(v, " ~ treatment + clash_dummy | case_id + month_id"))
  mod <- feols(model_formula, data = panel)
  violence_model_results[[v]] <- mod
  violence_model_results_twfe_main[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("TWFE + Clash:", model_name)),
    custom.coef.map = list(
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute"
    ),
    caption = paste("Effect of peace talks on", tolower(model_name)),
    caption.above = TRUE,
    include.ci = FALSE,
    stars = c(0.01, 0.05, 0.10),
    custom.note = "Standard errors in parentheses.")
  )
}

# TWFE treatment by case
for (v in violence_types) {
  model_name <- violence_labels[[v]]
  model_formula <- as.formula(paste0(v, " ~ tr_buenaventura + tr_arauca + tr_tumaco + clash_dummy | case_id + month_id"))
  mod <- feols(model_formula, data = panel)
  violence_model_results[[v]] <- mod
  violence_model_results_twfe[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("TWFE + Clash:", model_name)),
    custom.coef.map = list(
      "tr_buenaventura" = "Treatment: Buenaventura",
      "tr_arauca" = "Treatment: Arauca",
      "tr_tumaco" = "Treatment: Tumaco",
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
  model_formula <- as.formula(paste0(
    v, " ~ treatment + clash_dummy + treatment * clash_dummy | case_id + month_id"
  ))
  mod <- feols(model_formula, data = panel)
  violence_model_results[[v]] <- mod
  violence_model_results_twfe_interaction[[v]] <- mod
  cat("\nOutcome:", model_name, "(", v, ")\n")
  cat(screenreg(
    list(mod),
    custom.model.names = c(paste("TWFE + clash + interaction:", model_name)),
    custom.coef.map = list(
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment:clash_dummy" = "Peace talks × active dispute"
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
      "treatment" = "Peace talks active",
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
      "treatment" = "Peace talks active",
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
      "treatment" = "Peace talks active",
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
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment:clash_dummy" = "Peace talks × active dispute"
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
  "treatment" = "Peace talks active",
  "clash_dummy" = "Active armed-group dispute",
  "treatment:clash_dummy" = "Peace talks × active dispute",
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
      "treatment" = "Peace talks active",
      "clash_dummy" = "Active armed-group dispute",
      "treatment:clash_dummy" = "Peace talks x active dispute"
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
# 4. Coefficient plot
# -----------------------------------------------------------------------------

p_coef <- modelplot(
  list(
    "OLS" = m1,
    "Case FE" = m2,
    "TWFE" = m3,
    "TWFE + Clashes" = m4
  ),
  coef_map = c("treatment" = "Peace talks active")
) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  labs(
    title = "Treatment coefficient across model specifications",
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
    title = "Case-specific treatment coefficients from heterogeneous TWFE",
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
    Homicides_FE = to_df(violence_model_results_fe[["homicides"]], "Case FE + Clash: Homicides"),
    Terrorism_FE = to_df(violence_model_results_fe[["terrorism"]], "Case FE + Clash: Terrorism"),
    Extortion_FE = to_df(violence_model_results_fe[["extortion"]], "Case FE + Clash: Extortion"),
    Political_Violence_OLS = to_df(violence_model_results_ols[["political_violence"]], "General OLS + Clash: Political violence"),
    Civilian_Targeting_OLS = to_df(violence_model_results_ols[["civilian_targeting"]], "General OLS + Clash: Civilian targeting"),
    Homicides_OLS = to_df(violence_model_results_ols[["homicides"]], "General OLS + Clash: Homicides"),
    Terrorism_OLS = to_df(violence_model_results_ols[["terrorism"]], "General OLS + Clash: Terrorism"),
    Extortion_OLS = to_df(violence_model_results_ols[["extortion"]], "General OLS + Clash: Extortion"),
    Political_Violence_TWFE = to_df(violence_model_results_twfe_main[["political_violence"]], "TWFE + Clash: Political violence"),
    Civilian_Targeting_TWFE = to_df(violence_model_results_twfe_main[["civilian_targeting"]], "TWFE + Clash: Civilian targeting"),
    Homicides_TWFE = to_df(violence_model_results_twfe_main[["homicides"]], "TWFE + Clash: Homicides"),
    Terrorism_TWFE = to_df(violence_model_results_twfe_main[["terrorism"]], "TWFE + Clash: Terrorism"),
    Extortion_TWFE = to_df(violence_model_results_twfe_main[["extortion"]], "TWFE + Clash: Extortion"),
    Political_Violence_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["political_violence"]], "TWFE + Clash + Interaction: Political violence"),
    Civilian_Targeting_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["civilian_targeting"]], "TWFE + Clash + Interaction: Civilian targeting"),
    Homicides_TWFE_Interaction = to_df(violence_model_results_twfe_interaction[["homicides"]], "TWFE + Clash + Interaction: Homicides"),
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

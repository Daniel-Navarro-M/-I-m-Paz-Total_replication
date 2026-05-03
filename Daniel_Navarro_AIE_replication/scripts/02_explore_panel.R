# 02_explore.R
# Aggregate-only exploratory analysis for the monthly case panel.

options(stringsAsFactors = FALSE)

if (!requireNamespace("ggplot2", quietly = TRUE)) stop("Install ggplot2: install.packages('ggplot2')")
if (!requireNamespace("writexl", quietly = TRUE)) stop("Install writexl: install.packages('writexl')")
library(ggplot2)

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables/latex", recursive = TRUE, showWarnings = FALSE)

save_plot <- function(p, path, w = 9, h = 6, dpi = 150) {
  print(p)
  ggsave(path, p, width = w, height = h, dpi = dpi)
  cat("  Saved:", path, "\n")
}

dummy_intervals_from_panel <- function(panel_df, dummy_name) {
  out <- list()
  n <- 0
  for (cid in levels(panel_df$case_id)) {
    sub <- panel_df[panel_df$case_id == cid, c("case_id", "case_label", "month_start", dummy_name)]
    sub <- sub[order(sub$month_start), ]
    active <- sub[[dummy_name]] == 1
    if (!any(active, na.rm = TRUE)) next
    runs <- rle(active)
    ends <- cumsum(runs$lengths)
    starts <- ends - runs$lengths + 1
    for (i in seq_along(runs$values)) {
      if (!isTRUE(runs$values[i])) next
      n <- n + 1
      out[[n]] <- data.frame(
        case_id = sub$case_id[1],
        case_label = sub$case_label[1],
        xmin = sub$month_start[starts[i]],
        xmax = sub$month_start[ends[i]],
        stringsAsFactors = FALSE
      )
    }
  }
  if (!length(out)) {
    return(data.frame(case_id = character(), case_label = character(), xmin = as.Date(character()), xmax = as.Date(character())))
  }
  do.call(rbind, out)
}

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
  nice_names <- gsub("_", " ", names(fmt), fixed = TRUE)
  header <- paste(nice_names, collapse = " & ")
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
  cat("  Saved:", path, "\n")
}

panel <- readRDS("output/panel_monthly.rds")
panel$case_id <- factor(panel$case_id, levels = c("buenaventura", "arauca", "tumaco"))
panel$month_start <- as.Date(panel$month_start)

component_cols <- c(
  "political_violence",
  "civilian_targeting",
  "homicides",
  "terrorism",
  "extortion"
)
component_labels <- c(
  political_violence = "Political violence",
  civilian_targeting = "Civilian targeting",
  homicides = "Homicides",
  terrorism = "Terrorism",
  extortion = "Extortion"
)
component_colors <- c(
  political_violence = "#6A4C93",
  civilian_targeting = "#2A9D8F",
  homicides = "#D62828",
  terrorism = "#264653",
  extortion = "#F4A261"
)
names(component_colors) <- unname(component_labels[names(component_colors)])

component_long <- do.call(
  rbind,
  lapply(component_cols, function(v) {
    data.frame(
      case_id = panel$case_id,
      case_label = panel$case_label,
      month_start = panel$month_start,
      violence_type = component_labels[[v]],
      value = panel[[v]],
      stringsAsFactors = FALSE
    )
  })
)

cat("\n=== Aggregate panel overview ===\n")
cat("Rows:", nrow(panel), " | Columns:", ncol(panel), "\n")
cat("Cases:", paste(unique(as.character(panel$case_label)), collapse = ", "), "\n")
cat("Period:", min(panel$month_id), "to", max(panel$month_id), "\n")
cat("\nFirst rows:\n")
print(head(panel[, c("case_id", "month_id", "total_events", "treatment")]))

# -----------------------------------------------------------------------------
# Variable dictionary
# -----------------------------------------------------------------------------

dict_df <- data.frame(
  column_name = c(
    "case_id", "case_label", "spatial_definition", "month_id", "month_start",
    "total_events", "treatment", "clash_dummy", "gold_price", "oil_price", "cocaine_price", "month_index"
  ),
  description = c(
    "Study case identifier: buenaventura, arauca, tumaco.",
    "Human-readable study case label.",
    "Territorial scope of each study case.",
    "Calendar month in YYYY-MM format.",
    "First day of the month for plotting.",
    "Aggregate monthly count of all included observations across the merged Excel sources.",
    "Peace talks active in that case-month (1=yes, 0=no).",
    "Dummy equal to 1 in months with active armed-group dispute or clashes in the territorial case.",
    "Monthly gold price matched by month from gold.xlsx.",
    "Monthly oil price matched by month from oil.xlsx.",
    "Monthly cocaine price interpolated from yearly values.",
    "Sequential month index used for panel ordering."
  ),
  stringsAsFactors = FALSE
)
print(dict_df, row.names = FALSE)
writexl::write_xlsx(list(variable_dictionary = dict_df), "output/tables/variable_dictionary.xlsx")
write_latex_table(
  dict_df,
  "output/tables/latex/variable_dictionary.tex",
  "Variable dictionary for the aggregate panel.",
  "tab:variable_dictionary"
)

# -----------------------------------------------------------------------------
# Summary tables
# -----------------------------------------------------------------------------

summary_vars <- c("total_events", "treatment", "clash_dummy", "gold_price", "oil_price", "cocaine_price")

summ_all <- do.call(rbind, lapply(summary_vars, function(v) {
  x <- panel[[v]]
  data.frame(
    variable = v,
    mean = round(mean(x, na.rm = TRUE), 3),
    sd = round(sd(x, na.rm = TRUE), 3),
    min = round(min(x, na.rm = TRUE), 3),
    max = round(max(x, na.rm = TRUE), 3),
    stringsAsFactors = FALSE
  )
}))

summ_by_case <- do.call(rbind, lapply(levels(panel$case_id), function(cid) {
  sub <- panel[panel$case_id == cid, ]
  do.call(rbind, lapply(summary_vars, function(v) {
    x <- sub[[v]]
    data.frame(
      case_id = cid,
      variable = v,
      mean = round(mean(x, na.rm = TRUE), 3),
      sd = round(sd(x, na.rm = TRUE), 3),
      min = round(min(x, na.rm = TRUE), 3),
      max = round(max(x, na.rm = TRUE), 3),
      stringsAsFactors = FALSE
    )
  }))
}))

monthly_overview <- panel[, c("case_id", "case_label", "month_id", "total_events", "treatment", "clash_dummy")]

case_desc <- aggregate(total_events ~ case_id + case_label, data = panel, FUN = function(x) c(mean = mean(x), sd = sd(x), min = min(x), max = max(x)))
case_desc <- data.frame(
  case_id = case_desc$case_id,
  case_label = case_desc$case_label,
  mean = round(case_desc$total_events[, "mean"], 3),
  sd = round(case_desc$total_events[, "sd"], 3),
  min = round(case_desc$total_events[, "min"], 3),
  max = round(case_desc$total_events[, "max"], 3),
  stringsAsFactors = FALSE
)

onset <- aggregate(month_start ~ case_id + case_label, data = panel[panel$treatment == 1, ], FUN = min)
names(onset)[3] <- "treatment_onset"
treat_end <- aggregate(month_start ~ case_id + case_label, data = panel[panel$treatment == 1, ], FUN = max)
names(treat_end)[3] <- "treatment_end"

treat_months <- aggregate(treatment ~ case_id, data = panel, FUN = sum)
names(treat_months)[2] <- "treatment_months"
pre_months <- aggregate(treatment ~ case_id, data = panel, FUN = function(x) sum(x == 0))
names(pre_months)[2] <- "pre_treatment_months"

desc_table <- merge(case_desc, onset, by = c("case_id", "case_label"), all.x = TRUE)
desc_table <- merge(desc_table, pre_months, by = "case_id", all.x = TRUE)
desc_table <- merge(desc_table, treat_months, by = "case_id", all.x = TRUE)
desc_table <- desc_table[, c("case_label", "mean", "sd", "min", "max", "treatment_onset", "pre_treatment_months", "treatment_months")]
names(desc_table) <- c("Case", "mean", "sd", "min", "max", "t begin", "pre t months", "t months")

prepost_table <- do.call(rbind, lapply(levels(panel$case_id), function(cid) {
  sub <- panel[panel$case_id == cid, ]
  pre <- sub$total_events[sub$treatment == 0]
  post <- sub$total_events[sub$treatment == 1]
  clash_inactive <- sub$total_events[sub$clash_dummy == 0]
  clash_active <- sub$total_events[sub$clash_dummy == 1]
  data.frame(
    Case = unique(sub$case_label),
    pre_treatment_mean = round(mean(pre, na.rm = TRUE), 3),
    treatment_period_mean = round(mean(post, na.rm = TRUE), 3),
    difference = round(mean(post, na.rm = TRUE) - mean(pre, na.rm = TRUE), 3),
    clash_inactive_mean = round(mean(clash_inactive, na.rm = TRUE), 3),
    clash_active_mean = round(mean(clash_active, na.rm = TRUE), 3),
    clash_difference = round(mean(clash_active, na.rm = TRUE) - mean(clash_inactive, na.rm = TRUE), 3),
    stringsAsFactors = FALSE
  )
}))
names(prepost_table) <- c("Case", "pre t", "t", "diff", "no clash", "clash", "clash diff")

print(summ_all)
print(summ_by_case)
print(desc_table)
print(prepost_table)

writexl::write_xlsx(
  list(
    summary_all = summ_all,
    summary_by_case = summ_by_case,
    descriptive_table = desc_table,
    prepost_means = prepost_table,
    monthly_overview = monthly_overview
  ),
  "output/tables/summary_stats.xlsx"
)
write_latex_table(
  desc_table,
  "output/tables/latex/descriptive_table.tex",
  "Table 1: Small descriptive table with treatment timing by case.",
  "tab:descriptive_table"
)
write_latex_table(
  prepost_table,
  "output/tables/latex/prepost_means.tex",
  "Table 2: Pre-treatment, treatment-period, and clash-status means by case.",
  "tab:prepost_means"
)
write_latex_table(
  summ_all,
  "output/tables/latex/summary_all.tex",
  "Overall summary statistics for the aggregate panel.",
  "tab:summary_all"
)
write_latex_table(
  summ_by_case,
  "output/tables/latex/summary_by_case.tex",
  "Summary statistics by territorial case.",
  "tab:summary_by_case"
)
# -----------------------------------------------------------------------------
# Treatment onset
# -----------------------------------------------------------------------------

onset$onset_date <- onset$treatment_onset
print(onset[, c("case_id", "case_label", "onset_date")])

treat_window <- dummy_intervals_from_panel(panel, "treatment")
clash_window <- dummy_intervals_from_panel(panel, "clash_dummy")

print(clash_window)

# -----------------------------------------------------------------------------
# Total events over time
# -----------------------------------------------------------------------------

p_total <- ggplot(panel, aes(x = month_start, y = total_events)) +
  geom_rect(
    data = clash_window,
    aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
    inherit.aes = FALSE,
    fill = "#F4A261",
    alpha = 0.18
  ) +
  geom_vline(
    data = treat_window,
    aes(xintercept = xmin),
    inherit.aes = FALSE,
    color = "#1D3557",
    linewidth = 0.7
  ) +
  geom_vline(
    data = treat_window,
    aes(xintercept = xmax),
    inherit.aes = FALSE,
    color = "#1D3557",
    linewidth = 0.7,
    linetype = "dashed"
  ) +
  geom_line(color = "steelblue", linewidth = 0.9) +
  geom_point(color = "steelblue", size = 1.2) +
  geom_line(
    data = component_long,
    aes(x = month_start, y = value, color = violence_type, group = violence_type),
    inherit.aes = FALSE,
    linewidth = 0.75,
    linetype = "solid",
    alpha = 0.6
  ) +
  geom_smooth(method = "lm", se = FALSE, color = "firebrick", linewidth = 0.8) +
  facet_wrap(~ case_label, ncol = 1, scales = "free_y") +
  scale_color_manual(values = component_colors, name = "Violence type") +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(
    title = "Monthly aggregate event counts by study case",
    subtitle = "Blue solid line = total events; colored solid lines = component violence types; orange area = active armed-group dispute; solid/dashed blue vertical lines = peace talks start/end",
    x = NULL,
    y = "Monthly count of observations"
  ) +
  theme_bw() +
  theme(legend.position = "bottom")

save_plot(p_total, "output/figures/time_series_total.png", w = 9, h = 7)

# -----------------------------------------------------------------------------
# Distribution of total events
# -----------------------------------------------------------------------------

p_hist <- ggplot(panel, aes(x = total_events)) +
  geom_histogram(binwidth = 5, fill = "steelblue", color = "white") +
  facet_wrap(~ case_label, scales = "free_y") +
  labs(
    title = "Distribution of monthly aggregate event counts",
    x = "Total monthly observations",
    y = "Frequency"
  ) +
  theme_bw()

save_plot(p_hist, "output/figures/hist_total_events.png", w = 9, h = 5)

p_box <- ggplot(panel, aes(x = case_label, y = total_events, fill = case_label)) +
  geom_boxplot(alpha = 0.8, outlier.alpha = 0.5) +
  labs(
    title = "Distribution of aggregate monthly events by study case",
    x = NULL,
    y = "Total monthly observations"
  ) +
  theme_bw() +
  theme(legend.position = "none")

save_plot(p_box, "output/figures/boxplot_total_events_by_case.png", w = 8, h = 5)

# -----------------------------------------------------------------------------
# Pre/post mean comparison by case
# -----------------------------------------------------------------------------

prepost_long <- rbind(
  data.frame(case_label = prepost_table[["Case"]], period = "Pre-treatment", mean_events = prepost_table[["pre t"]]),
  data.frame(case_label = prepost_table[["Case"]], period = "Treatment", mean_events = prepost_table[["t"]])
)

p_prepost <- ggplot(prepost_long, aes(x = case_label, y = mean_events, fill = period)) +
  geom_col(position = "dodge") +
  labs(
    title = "Pre-treatment and treatment-period mean events by case",
    x = NULL,
    y = "Mean monthly aggregate events",
    fill = NULL
  ) +
  theme_bw()

save_plot(p_prepost, "output/figures/prepost_means_by_case.png", w = 8, h = 5)

cat("\n=== 02_explore.R complete ===\n")
cat("Figures: output/figures/\n")
cat("Tables : output/tables/\n")

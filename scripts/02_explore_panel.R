# 02_explore.R
# Aggregate-only exploratory analysis for the monthly case panel.

options(stringsAsFactors = FALSE)

library(ggplot2)
library(ggridges)
library(ggthemes)
library(gghighlight)
library(ggforce)
library(dplyr)
library(tidyverse)
library(broom)
library(openintro)
library(infer)

dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables", recursive = TRUE, showWarnings = FALSE)
dir.create("output/tables/latex", recursive = TRUE, showWarnings = FALSE)

# Loading the data ----

# we get wide data first
panel <- read_csv("data/processed/panel_wide.csv")
panel$case_id <- factor(panel$case_id, levels = c("buenaventura", "arauca", "tumaco"))

panel_long <- read_csv("./data/processed/panel_long.csv")

# Add aggregate "All" case (sum across all 3 cases)
panel_long_all <- panel_long |>
  group_by(month_start, violence_type, treatment_dummy, clash_dummy) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  mutate(case_id = "All")

panel_long <- bind_rows(
  panel_long |> mutate(case_id = as.character(case_id)),
  panel_long_all
) |>
  mutate(case_id = factor(case_id, levels = c("All", "arauca", "buenaventura", "tumaco")))

hist(panel_long$count)

mean(panel_long$count)
var(panel_long$count)

## Setting colors ----
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

## Custom theme ----

thesis_theme <- function() {
  theme_bw() +
  theme(
    axis.ticks = element_blank(),
    axis.text = element_text(size = 12),
    axis.title = element_text(size = 13),
    legend.title = element_text(size = 11),
    legend.text = element_text(size = 10),
    legend.position = "bottom",
    legend.box.background = element_blank(),
    legend.background = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.background = element_rect(fill = "white"),
    plot.title = element_text(size = 14, face = "bold"),
    plot.subtitle = element_text(size = 12),
    text = element_text(family = "sans")
  )
}

## Variable dictionary ----

dict_df <- data.frame(
  column_name = c(
    "case_id", "case_label", "spatial_definition", "month_id", "month_start",
    "total_events", "treatment", "clash_dummy", "month_index"
  ),
  description = c(
    "Study case identifier: buenaventura, arauca, tumaco.",
    "Study case label.",
    "Territorial scope of each study case.",
    "Calendar month in YYYY-MM format.",
    "First day of the month for plotting.",
    "Aggregate monthly count of all violences.",
    "Peace talks active in that case-month (1=yes, 0=no).",
    "Dummy equal to 1 in months with active armed-group clashes in the territorial case.",
    "Sequential month index used for panel ordering."
  ),
  stringsAsFactors = FALSE)

print(dict_df, row.names = FALSE)
writexl::write_xlsx(list(variable_dictionary = dict_df), "output/tables/variable_dictionary.xlsx")
knitr::kable(
  dict_df,
  format = "latex",
  caption = "Variable dictionary for the aggregate panel.",
  label = "variable_dictionary",
  booktabs = TRUE
) |> writeLines("output/tables/latex/variable_dictionary.tex")

# Summary tables and visualizations ----

# Treatment effects: violence types (entire dataset) ----
panel_long_cases <- panel_long |> filter(case_id != "All")

treatment_effect_means_all <- panel_long_cases |>
  group_by(violence_type, treatment_dummy) |>
  summarise(
    group_mean = mean(count, na.rm = TRUE),
    se = sd(count, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = "drop"
  ) |>
  mutate(case_id = "All")

treatment_effect_means_case <- panel_long_cases |>
  group_by(case_id, violence_type, treatment_dummy) |>
  summarise(
    group_mean = mean(count, na.rm = TRUE),
    se = sd(count, na.rm = TRUE) / sqrt(n()),
    n = n(),
    .groups = "drop")

treatment_effect_means <- bind_rows(treatment_effect_means_all, treatment_effect_means_case)

### Visualization: treatment effects by violence type ----

treatment_case <- ggplot(treatment_effect_means,
       aes(x = violence_type,
           y = group_mean,
           shape = factor(treatment_dummy),
           color = case_id)) +
  geom_point(size = 2, position = position_dodge(width = 0.45)) +
  geom_errorbar(aes(ymin = group_mean - 1.96 * se, ymax = group_mean + 1.96 * se), 
                position = position_dodge(width = 0.45), width = 0.1) +
  scale_x_discrete(labels = component_labels) +
  labs(
    y = "Mean monthly events", 
    x = "Type of violence",
    title = "Monthly events pre and post treatment (case)",
    subtitle = "Points show means, error bars show 95% CIs",
    caption = "Source: ACLED and Policia Nacional de Colombia"
  ) + 
  thesis_theme()

ggsave(treatment_case, file = "output/figures/mean_events_prepost.png", height = 6, width = 8,
       units = "in", dpi = 320)

### t-tests for each violence type and case ----
treatment_tests <- expand_grid(
  case_id = unique(treatment_effect_means$case_id),
  violence_type = unique(treatment_effect_means$violence_type)
) |>
  mutate(
    test = pmap(list(case_id, violence_type), ~{
      case <- ..1
      vtype <- ..2
      
      # Filter data: "All" means all cases, otherwise specific case
      if (case == "All") {
        data <- panel_long |> filter(violence_type == vtype)
      } else {
        data <- panel_long |> filter(violence_type == vtype, case_id == case)
      }
      
      if (nrow(data) > 0) {
        data |> t_test(count ~ treatment_dummy, order = c(1, 0))
      } else {
        NULL
      }
    })
  ) |>
  unnest(test)

# Summary table: treatment effects with significance tests
treatment_summary <- treatment_effect_means |>
  select(case_id, violence_type, treatment_dummy, group_mean) |>
  pivot_wider(
    names_from = treatment_dummy, 
    values_from = group_mean,
    values_fn = mean  # Summarise duplicates by taking the mean
  ) |>
  rename(
    `pre-treatment` = `0`,
    treatment = `1`
  ) |>
  mutate(
    difference = treatment - `pre-treatment`, 
    t_stat = NA_real_, 
    p_value = NA_real_
  )

for (i in seq_len(nrow(treatment_summary))) {
  vtype <- treatment_summary$violence_type[i]
  cid <- treatment_summary$case_id[i]
  test <- treatment_tests |> 
    filter(violence_type == vtype, case_id == cid)
  
  if (nrow(test) > 0) {
    treatment_summary$t_stat[i] <- test$statistic[1]
    treatment_summary$p_value[i] <- test$p_value[1]
  }
}

treatment_summary <- treatment_summary |>
  select(case_id, violence_type, `pre-treatment`, treatment, difference, t_stat, p_value) |>
  mutate(
    across(c(`pre-treatment`, treatment, difference, t_stat), ~round(., 3))
  ) |>
  rename(Case = case_id, 
         Violence_Type = violence_type, 
         Pre_treatment = `pre-treatment`, 
         Treatment = treatment, 
         Difference = difference, 
         t_stat_val = t_stat) |>
  mutate(
    significance = case_when(
      p_value < 0.001 ~ "***",
      p_value < 0.01 ~ "**",
      p_value < 0.05 ~ "*",
      TRUE ~ ""
    ),
    p_value_val = paste0(format(round(p_value, 4), nsmall = 4), significance)
  ) |>
  select(Case, Violence_Type, Pre_treatment, Treatment, Difference, t_stat_val, p_value_val) |>
  mutate(Case = str_to_title(Case))

print(treatment_summary)

# Create separate tables for each case
cases_to_export <- c("All", "Arauca", "Buenaventura", "Tumaco")

for (case_name in cases_to_export) {
  table_data <- treatment_summary |>
    filter(Case == case_name) |>
    select(Violence_Type, Pre_treatment, Treatment, Difference, p_value_val) |>
    rename(
      `Violence Type` = Violence_Type,
      `Pre-treatment` = Pre_treatment,
      `Treatment` = Treatment,
      `Difference` = Difference,
      `P-value` = p_value_val
    )
  
  # Create caption with case name
  caption_text <- paste("Treatment effects on violence types:", case_name)
  label_text <- tolower(paste0("tab:treatment_", gsub(" ", "_", case_name)))
  
  # Export to LaTeX
  knitr::kable(table_data, format = "latex",
               caption = caption_text,
               label = label_text,
               booktabs = TRUE) |>
    writeLines(paste0("output/tables/latex/treatment_effects_", tolower(gsub(" ", "_", case_name)), ".tex"))
  
  # Print to console
  cat("\n=== ", case_name, " ===\n", sep = "")
  print(table_data)
}

### Violin plot with observations by case ----

p_violin <- ggplot(panel_long, aes(x = violence_type, y = count, fill = violence_type)) +
  geom_violin(width = 0.6, alpha = 0.5) +
  geom_sina(maxwidth = 0.6, alpha = 0.4, size = 0.5) +
  facet_wrap(~case_id, scales = "free_x", ncol = 2,
             labeller = labeller(case_id = component_labels)) +
  scale_x_discrete(labels = component_labels) +
  scale_fill_manual(values = component_colors, labels = component_labels) +
  labs(
    title = "Distribution of violence events by case and treatment period",
    x = "Violence type",
    y = "Monthly count",
    caption = "Source: ACLED and Policia Nacional de Colombia"
  ) +
  thesis_theme() + theme(legend.position = "none") +
  coord_flip()

ggsave(p_violin, file="output/figures/violin_by_case.png", height = 6, width = 8,
       units = "in", dpi = 320)

### Event counts by violence type and treatment (stacked bar) ----
p_violence_comp <- panel_long |> mutate(
  treatment_label = factor(
    treatment_dummy,
    levels = c(0, 1),
    labels = c("Untreated", "Treated")
  )) |> 
  group_by(case_id, violence_type, treatment_label) |>
  summarise(total_count = sum(count, na.rm = TRUE), .groups = "drop") |>
  ggplot(aes(x = violence_type, y = total_count, fill = treatment_label)) +
  geom_col(position = "dodge") +
  facet_wrap(~case_id) +
  scale_x_discrete(labels = component_labels) +
  labs(
    title = "Total violence events by type and treatment period",
    x = "Violence type",
    y = "Total count",
    fill = "Period"
  ) +
  thesis_theme() + coord_flip()

ggsave(p_violence_comp, file = "output/figures/stacked_bar_events.png",
       height = 6, width = 8,
       units = "in", dpi = 320)


### timeseries at the case level -----

clash_periods_plot <- read_csv("data/Raw/clash_periods.csv")

case_name_map <- c(
  "buenaventura" = "Buenaventura",
  "arauca" = "Arauca",
  "tumaco" = "Tumaco"
)

clash_periods_plot <- clash_periods_plot |> mutate(
  case_id = str_to_lower(str_squish(municipio)),
  case_label = recode(case_id, !!!case_name_map, .default = str_to_title(case_id)),
  start_date = as.Date(start_date, format = "%d/%m/%Y"),
  end_date = as.Date(end_date, format = "%d/%m/%Y"))

periods <- read_csv("data/raw/treatment_periods.csv")

periods <- periods |> mutate(
  case_id = str_to_lower(str_squish(municipio)),
  case_label = recode(case_id, !!!case_name_map, .default = str_to_title(case_id)),
  start_date = as.Date(start_date, format = "%d/%m/%Y"),
  end_date = as.Date(end_date, format = "%d/%m/%Y"))

panel_long_line <- panel_long |> filter(case_id != "All") |> mutate(case_label = stringr::str_to_title(case_id))
total_df <- panel_long_line |>
  group_by(case_id, case_label, month_start) |>
  summarise(total_count = sum(count, na.rm = TRUE), .groups = "drop")

panel_min <- min(panel_long_line$month_start, na.rm = TRUE)
panel_max <- max(panel_long_line$month_start, na.rm = TRUE)

clash_periods_plot <- clash_periods_plot |>
  mutate(
    start_date = pmax(start_date, panel_min),
    end_date = pmin(end_date, panel_max)
  ) |>
  filter(!is.na(start_date), !is.na(end_date), start_date <= end_date)

periods <- periods |>
  mutate(
    start_date = pmax(start_date, panel_min),
    end_date = pmin(end_date, panel_max)
  ) |>
  filter(!is.na(start_date), !is.na(end_date), start_date <= end_date)

p_total <- ggplot(panel_long_line, aes(x = month_start, y = count,
                                  group = interaction(case_id, violence_type),
                                  color = violence_type)) +
  # individual lines
  geom_line(
    linewidth = 0.75,
    alpha = 0.7,
    linejoin = "round",
    lineend = "round"
  ) +
  
  # TOTAL line
  geom_line(
    data = total_df,
    aes(x = month_start, y = total_count, group = case_id),
    inherit.aes = FALSE,
    color = "blue",
    linewidth = 0.8,
    lineend = "round",
    linejoin = "round") +
  
  geom_smooth(se = FALSE, method = "gam", formula = y ~ s(x, bs = "cs"),
              alpha = 0.6, linetype = "dashed", linewidth = 0.4) +
  
  geom_smooth(data = total_df, aes(x = month_start, y = total_count, 
                                   group = case_id),
              inherit.aes = FALSE, se = FALSE, method = "gam", formula = y ~ s(x, bs = "cs"),
              alpha = 0.6, linetype = "dashed", linewidth = 0.4) +
  
  geom_rect(
    data = clash_periods_plot,
    aes(xmin = start_date, xmax = end_date, ymin = -Inf, ymax = Inf, fill = "Clash period"),
    inherit.aes = FALSE,
    alpha = 0.12
  ) +
  
  geom_vline(
    data = periods,
    aes(xintercept = start_date, linetype = "Treatment start"),
    color = "black",
    linewidth = 0.8,
    alpha = 1.0
  ) +
  geom_vline(
    data = periods,
    aes(xintercept = end_date, linetype = "Treatment end"),
    color = "black",
    linewidth = 0.8,
    alpha = 1
  ) +
  facet_wrap(~ case_label, ncol = 1, scales = "free_y") +
  scale_fill_manual(name = NULL, values = c("Clash period" = "#F4A261")) +
  scale_linetype_manual(
    name = NULL,
    values = c("Treatment start" = "solid", "Treatment end" = "dashed")
  ) +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  labs(
    title = "Monthly aggregate event counts by study case",
    x = NULL,
    y = "Monthly count of observations"
  ) +
  thesis_theme()

ggsave(
  filename = "output/figures/time_series.png",
  plot = p_total,
  width = 10,
  height = 7,
  units = "in",
  dpi = 320
)

### timeseries Colombia level ----

panel_col_long <- read_csv("data/processed/panel_long_col.csv")

dept_by_type <- panel_col_long |>
  rename(departamento = departamento_std) |>
  mutate(departamento = str_to_title(departamento)) |>
  group_by(month_start, departamento, violence_type) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop")

# 6th panel: total events (sum across violence types) by department
dept_total <- dept_by_type |>
  group_by(month_start, departamento) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop") |>
  mutate(violence_type = "total")

# National reference: use national average (NOT national total)
national_avg_by_type <- dept_by_type |>
  group_by(month_start, violence_type) |>
  summarise(count = mean(count, na.rm = TRUE), .groups = "drop") |>
  mutate(departamento = "National")

national_avg_total <- dept_total |>
  group_by(month_start, violence_type) |>
  summarise(count = mean(count, na.rm = TRUE), .groups = "drop") |>
  mutate(departamento = "National")

dept_plot <- bind_rows(
  dept_by_type,
  dept_total,
  national_avg_by_type,
  national_avg_total
) |>
  mutate(
    highlight = departamento %in% c("Valle Del Cauca", "Arauca", "Nariño", "National"),
    line_group = case_when(
      departamento == "Valle Del Cauca" ~ "Valle Del Cauca",
      departamento == "Arauca" ~ "Arauca",
      departamento == "Nariño" ~ "Nariño",
      departamento == "National" ~ "National average",
      TRUE ~ "Other departments"
    ),
    violence_type = factor(
      violence_type,
      levels = c("political_violence", "civilian_targeting", "homicide", "terrorism", "extortion", "total"),
      labels = c(
        unname(component_labels["political_violence"]),
        unname(component_labels["civilian_targeting"]),
        "Homicide",
        unname(component_labels["terrorism"]),
        unname(component_labels["extortion"]),
        "Total"
      )
    )
  )

line_colors <- c(
  "Valle Del Cauca" = "#D62828",
  "Arauca" = "#6A4C93",
  "Nariño" = "#2A9D8F",
  "National average" = "steelblue",
  "Other departments" = "gray70"
)

p_dept_combined <- ggplot(
  dept_plot,
  aes(
    x = month_start,
    y = count,
    group = departamento,
    color = line_group,
    alpha = highlight
  )
) +
  geom_line(linewidth = 0.35, linejoin = "round", lineend = "round") +
  scale_alpha_manual(values = c("TRUE" = 0.95, "FALSE" = 0.25), guide = "none") +
  scale_color_manual(values = line_colors, name = "Department") +
  scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
  facet_wrap(~ violence_type, ncol = 1, scales = "free_y") +
  labs(
    title = "Violence trends by department and type",
    x = NULL,
    y = "Monthly count"
  ) +
  thesis_theme()

ggsave(
  filename = "output/figures/national_department_trends.png",
  plot = p_dept_combined,
  width = 8,
  height = 10,
  units = "in",
  dpi = 320
)


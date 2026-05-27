# 05_did_country_robustness.R
# Country-wide DiD as a robustness check on the case-level main analysis.
#
# Three specifications, in plain English:
#   1. FULL PANEL DiD     - all Colombian departments + 3 case units.
#                           Treated = 25 units (3 cases + 22 departments
#                           touched by any Paz Total mesa). Controls =
#                           the 10 remaining never-treated departments:
#                           Amazonas, Bogota D.C., Boyaca, Caldas,
#                           Cundinamarca, Guainia, Quindio, San Andres,
#                           Vaupes, Vichada. No clash control.
#   2. NARROW PANEL DiD   - same treated set, but controls restricted to
#                           the 4 mainland-Andean similar departments
#                           (Cundinamarca, Boyaca, Caldas, Quindio).
#                           The other 6 untreated units are dropped:
#                           Bogota (urban capital with own dynamics),
#                           Amazonas/Guainia/Vaupes/Vichada (sparse
#                           population, near-zero event counts), San
#                           Andres (Caribbean island, no conflict
#                           events). No clash control.
#   3. CASES + CLASH DiD  - 3 study cases (Buenaventura, Arauca, Tumaco)
#                           against the 4 narrow controls, with clash
#                           control + interaction (matches the main spec
#                           from 03_estimate_models.R).
#
# Two "Post" coding choices in 1 and 2:
#   ACTIVE      - treatment = 1 only during active mesa months.
#   PERMANENT   - treatment = 1 from first mesa onward, even if suspended.
#
# Diagnostics: event-study plot, Wald pre-trends test, raw-trends plot,
# linear slope-difference test. Clash control is omitted from 1 and 2
# because clash periods are coded only for the 3 study cases.

options(stringsAsFactors = FALSE)


# 0. Setup -------------------------------------------------------------------

library(fixest); library(texreg); library(broom); library(ggplot2)
library(readr);  library(dplyr);  library(tidyr);  library(stringr)
library(lubridate)

dir.create("output/tables",  recursive = TRUE, showWarnings = FALSE)
dir.create("output/figures", recursive = TRUE, showWarnings = FALSE)

unaccent <- function(x) chartr("áéíóúñüÁÉÍÓÚÑÜ", "aeiounuAEIOUNU", x)

thesis_theme <- function() {
  theme_bw() +
    theme(axis.ticks = element_blank(),
          axis.text  = element_text(size = 12),
          axis.title = element_text(size = 13),
          legend.position = "bottom",
          panel.background = element_rect(fill = "white"),
          plot.background  = element_rect(fill = "white"),
          plot.title = element_text(size = 14, face = "bold"),
          plot.subtitle = element_text(size = 11),
          text = element_text(family = "sans"))
}

plot_event_study <- function(es, title, plot_path, ref_period = -1L) {
  td <- broom::tidy(es, conf.int = TRUE) |>
    dplyr::filter(grepl("^event_time_es::", term)) |>
    dplyr::mutate(period = as.integer(sub("event_time_es::", "", term))) |>
    dplyr::filter(period > -100)
  td <- dplyr::bind_rows(td, dplyr::tibble(
    term = sprintf("event_time_es::%d", ref_period),
    estimate = 0, conf.low = 0, conf.high = 0, period = ref_period)) |>
    dplyr::arrange(period) |>
    dplyr::mutate(phase = dplyr::if_else(period < 0, "Pre-treatment", "Post-treatment"))
  p <- ggplot(td, aes(x = period, y = estimate)) +
    geom_hline(yintercept = 0,    linetype = "dashed", color = "grey40") +
    geom_vline(xintercept = -0.5, linetype = "dashed", color = "grey40") +
    geom_ribbon(aes(ymin = conf.low, ymax = conf.high),
                fill = "steelblue", alpha = 0.18) +
    geom_line(color = "steelblue") +
    geom_point(aes(color = phase), size = 2.2) +
    scale_color_manual(values = c("Pre-treatment"  = "steelblue",
                                   "Post-treatment" = "firebrick")) +
    labs(title = title,
         x = "Months since first treatment",
         y = "Event-study coefficient (95% CI)", color = NULL) +
    thesis_theme()
  ggsave(plot_path, p, width = 14, height = 5, dpi = 150)
  invisible(p)
}


# Hand-picked never-treated controls (no Paz Total mesa names them; any
# armed presence comes from groups outside Paz Total).
SIMILAR_CONTROLS <- unaccent(c("cundinamarca", "boyaca", "caldas", "quindio"))


# 1. Load and prepare panel --------------------------------------------------

panel <- read_csv("data/Processed/panel_long_col.csv", show_col_types = FALSE)
panel$month_start <- as.Date(paste0(panel$month_id, "-01"))
panel$unit_id <- unaccent(
  ifelse(is.na(panel$case_id), panel$departamento_std, panel$case_id)
)

# Consolidate inconsistent source naming so each administrative unit
# is one cluster. ACLED writes "Bogota D.C." while Police writes
# "Bogota, D.C." with a comma; after lowercase + unaccent they remain
# two distinct strings, which inflates the cluster count and treats
# Bogota as two separate units. Same issue for San Andres ("san andres
# islas" vs "san andres y providencia"). After this step:
#   - all Bogota rows have unit_id = "bogota d.c."
#   - all San Andres rows have unit_id = "san andres y providencia"
# so the collapse step below sums their events into one row per
# admin-unit-month, and the regressions cluster on the admin unit
# rather than on its source-specific label.
panel$unit_id <- case_when(
  panel$unit_id %in% c("bogota d.c.", "bogota, d.c.") ~ "bogota d.c.",
  panel$unit_id %in% c("san andres islas",
                       "san andres y providencia")    ~ "san andres y providencia",
  TRUE                                                 ~ panel$unit_id
)

# Collapse violence types to one count per unit-month.
panel_did <- panel |>
  group_by(unit_id, month_id, month_start) |>
  summarise(count = sum(count, na.rm = TRUE), .groups = "drop")

# Treatment periods (3 cases + country tracks).
cases <- read_csv("data/raw/treatment_periods.csv", show_col_types = FALSE) |>
  mutate(municipio  = unaccent(str_to_lower(str_squish(municipio))),
         start_date = as.Date(start_date, format = "%d/%m/%Y"),
         end_date   = as.Date(end_date,   format = "%d/%m/%Y"))
country <- read_csv("data/raw/treatment_periods_country.csv",
                    show_col_types = FALSE) |>
  mutate(municipio  = unaccent(str_to_lower(str_squish(municipio))),
         start_date = as.Date(start_date, format = "%d/%m/%Y"),
         end_date   = as.Date(end_date,   format = "%d/%m/%Y"))
all_periods <- bind_rows(
  cases   |> select(municipio, start_date, end_date),
  country |> select(municipio, start_date, end_date)
)

# ACTIVE indicator: 1 inside any [start, end] window (union across groups).
panel_did$treatment_dummy <- 0L
for (i in seq_len(nrow(all_periods))) {
  panel_did$treatment_dummy[
    panel_did$unit_id == all_periods$municipio[i] &
      panel_did$month_start >= all_periods$start_date[i] &
      panel_did$month_start <= all_periods$end_date[i]
  ] <- 1L
}

# PERMANENT indicator: 1 from each unit's earliest start onward.
first_treat <- all_periods |>
  group_by(municipio) |>
  summarise(first_treat_date = min(start_date, na.rm = TRUE), .groups = "drop")

panel_did <- panel_did |>
  left_join(first_treat, by = c("unit_id" = "municipio")) |>
  mutate(
    ever_treated = as.integer(!is.na(first_treat_date)),
    post_dummy   = as.integer(!is.na(first_treat_date) &
                              month_start >= first_treat_date),
    event_time = if_else(
      is.na(first_treat_date), NA_integer_,
      as.integer(12 * (year(month_start) - year(first_treat_date)) +
                   (month(month_start) - month(first_treat_date)))),
    event_time_es = if_else(is.na(event_time), -999L, event_time)
  )

# Bring clash_dummy from the 3-case panel (NA -> 0 for other units).
panel_cases <- read_csv("data/Processed/panel_long.csv", show_col_types = FALSE)
case_clash <- panel_cases |>
  group_by(case_id, month_id) |>
  summarise(clash_dummy = max(clash_dummy), .groups = "drop") |>
  rename(unit_id = case_id) |>
  mutate(unit_id = unaccent(unit_id))
panel_did <- panel_did |>
  left_join(case_clash, by = c("unit_id", "month_id")) |>
  mutate(clash_dummy = if_else(is.na(clash_dummy), 0L, clash_dummy))


# 2. Reference: 3-case main spec ---------------------------------------------

panel_cases$month_start <- as.Date(paste0(panel_cases$month_id, "-01"))
m_ref <- feols(count ~ treatment_dummy + clash_dummy +
                       treatment_dummy:clash_dummy | case_id + month_id,
               data = panel_cases, cluster = ~case_id)
screenreg(list(m_ref), custom.model.names = "Reference (3-case + clash)",
          stars = c(0.01, 0.05, 0.10))


# 3. FULL PANEL DiD ----------------------------------------------------------
# Treated = 25 units (3 cases + 22 departments touched by any mesa).
# Control = the 10 remaining never-treated departments.

m_full_active <- feols(count ~ treatment_dummy | unit_id + month_id,
                       data = panel_did, cluster = ~unit_id)
m_full_post   <- feols(count ~ post_dummy      | unit_id + month_id,
                       data = panel_did, cluster = ~unit_id)
screenreg(list(m_full_active, m_full_post),
          custom.model.names = c("Full / Active", "Full / Permanent"),
          stars = c(0.01, 0.05, 0.10))

es_full <- feols(count ~ i(event_time_es, ref = c(-1, -999)) |
                          unit_id + month_id,
                 data = panel_did, cluster = ~unit_id)
wald(es_full, keep = "^event_time_es::-(2[0-4]|1[0-9]|[2-9])$")
plot_event_study(es_full,
                 "Full panel DiD - all 37 departments",
                 "output/figures/event_study_full.png")


# 4. NARROW PANEL DiD --------------------------------------------------------
# Treated = same 20 departments. Control = 4 hand-picked similar
# untreated departments (Cundinamarca, Boyaca, Caldas, Quindio).

treated_units <- unique(all_periods$municipio)
panel_narrow  <- panel_did[panel_did$unit_id %in% c(treated_units,
                                                     SIMILAR_CONTROLS), ]

m_narrow_active <- feols(count ~ treatment_dummy | unit_id + month_id,
                         data = panel_narrow, cluster = ~unit_id)
m_narrow_post   <- feols(count ~ post_dummy      | unit_id + month_id,
                         data = panel_narrow, cluster = ~unit_id)
screenreg(list(m_narrow_active, m_narrow_post),
          custom.model.names = c("Narrow / Active", "Narrow / Permanent"),
          stars = c(0.01, 0.05, 0.10))

es_narrow <- feols(count ~ i(event_time_es, ref = c(-1, -999)) |
                            unit_id + month_id,
                   data = panel_narrow, cluster = ~unit_id)
wald(es_narrow, keep = "^event_time_es::-(2[0-4]|1[0-9]|[2-9])$")
plot_event_study(es_narrow,
                 "Narrow panel DiD - treated + 4 similar controls",
                 "output/figures/event_study_narrow.png")


# 5. CASES + CLASH DiD -------------------------------------------------------
# 3 study cases (with real clash_dummy) plus 4 narrow controls
# (clash_dummy = 0 by construction, no clash data outside the cases).
# Matches the case-level main spec but adds the narrow controls.
# NOTE: parallel trends are violated in the broader DiD (see Step 4
# Wald test), AND the 3 cases are not theoretically comparable to the
# 4 controls (different conflict logics). This spec is exploratory.

case_units <- c("buenaventura", "arauca", "tumaco")
panel_clash <- panel_did[panel_did$unit_id %in% c(case_units,
                                                    SIMILAR_CONTROLS), ]

m_clash <- feols(count ~ treatment_dummy + clash_dummy +
                          treatment_dummy:clash_dummy |
                          unit_id + month_id,
                  data = panel_clash, cluster = ~unit_id)
screenreg(list(m_ref, m_clash),
          custom.model.names = c("Main (3 cases)",
                                  "Cases + narrow controls + clash"),
          stars = c(0.01, 0.05, 0.10))


# 6. Raw trends in calendar time ---------------------------------------------

treated_units <- unique(all_periods$municipio)
calendar_trends <- panel_did |>
  mutate(group = case_when(
    unit_id %in% treated_units    ~ "Treated (eventually)",
    unit_id %in% SIMILAR_CONTROLS ~ "Narrow control",
    TRUE                          ~ "Other untreated")) |>
  group_by(month_start, group) |>
  summarise(mean_count = mean(count, na.rm = TRUE), .groups = "drop")

first_mesa_date <- min(all_periods$start_date)

p_trends <- ggplot(calendar_trends,
                    aes(x = month_start, y = mean_count, color = group)) +
  geom_vline(xintercept = first_mesa_date, linetype = "dashed",
             color = "grey40") +
  geom_line(alpha = 0.35, linewidth = 0.5) +
  geom_smooth(method = "loess", span = 0.4, se = FALSE, linewidth = 1) +
  scale_color_manual(values = c("Treated (eventually)" = "firebrick",
                                 "Narrow control"      = "steelblue",
                                 "Other untreated"     = "grey55")) +
  labs(title = "Monthly violence by group (calendar time)",
       subtitle = "Vertical line = first Paz Total mesa (Buenaventura, 2022-09)",
       x = NULL, y = "Mean events per unit-month", color = NULL) +
  thesis_theme()
ggsave("output/figures/raw_trends_calendar.png", p_trends,
       width = 12, height = 5, dpi = 150)


# 7. Pre-trends focus (slope comparison, treated vs narrow control) ----------
# Dashed lines = linear fit. If they're parallel, slopes are parallel.

pre_focus <- calendar_trends |>
  filter(month_start < first_mesa_date,
         group %in% c("Treated (eventually)", "Narrow control"))

p_pre_focus <- ggplot(pre_focus,
                       aes(x = month_start, y = mean_count, color = group)) +
  geom_line(alpha = 0.35, linewidth = 0.5) +
  geom_smooth(method = "loess", span = 0.4, se = FALSE, linewidth = 1) +
  geom_smooth(method = "lm",    se = FALSE, linetype = "dashed",
              linewidth = 0.7) +
  scale_color_manual(values = c("Treated (eventually)" = "firebrick",
                                 "Narrow control"      = "steelblue")) +
  labs(title = "Pre-treatment trends: treated vs. narrow control",
       subtitle = "Solid = LOESS smooth.  Dashed = linear fit (slope).",
       x = NULL, y = "Mean events per unit-month", color = NULL) +
  thesis_theme()
ggsave("output/figures/pre_trends_focus.png", p_pre_focus,
       width = 12, height = 5, dpi = 150)


# 8. Pre-trends slope test (scalar long-run check) ---------------------------

pre_data <- calendar_trends |> filter(month_start < first_mesa_date)
pre_slopes <- pre_data |>
  group_by(group) |>
  summarise(n_months = n(),
            slope_per_year = coef(lm(mean_count ~ month_start))[2] * 365.25,
            slope_p_value  = summary(lm(mean_count ~ month_start))$coefficients[2, 4],
            .groups = "drop")
print(pre_slopes)

pre_diff <- pre_data |>
  filter(group %in% c("Treated (eventually)", "Narrow control")) |>
  mutate(t = as.numeric(month_start),
         is_treated = as.integer(group == "Treated (eventually)"))
slope_diff_model <- lm(mean_count ~ t * is_treated, data = pre_diff)
print(summary(slope_diff_model)$coefficients["t:is_treated", , drop = FALSE])


# 9. Headline table ----------------------------------------------------------

screenreg(list(m_ref, m_full_active, m_full_post,
               m_narrow_active, m_narrow_post, m_clash),
          custom.model.names = c("Main", "Full/Active", "Full/Perm",
                                  "Narrow/Active", "Narrow/Perm",
                                  "Cases+ctrls+clash"),
          stars = c(0.01, 0.05, 0.10))

writeLines(
  etable(m_full_active, m_full_post, m_narrow_active, m_narrow_post, m_clash,
         headers = c("Full/Active", "Full/Perm",
                     "Narrow/Active", "Narrow/Perm",
                     "Cases+ctrls+clash"),
         title  = "DiD robustness: full panel, narrow panel, and cases + clash.",
         label  = "tab:did_robustness",
         notes  = "Standard errors clustered at the unit level.",
         tex    = TRUE),
  "output/tables/did_robustness.tex"
)


# 10. Combined event-study plot (full vs narrow, side by side) ---------------
# Same data the two individual plots use, faceted into one image so
# differences in pre-period drift and post-period bounce-around are
# directly comparable. If the two facets look identical, something
# is wrong with the controls (see commit history -- this was the bug
# in the pre-fix runs).

es_combined <- bind_rows(
  broom::tidy(es_full,   conf.int = TRUE) |> mutate(panel = "Full panel (all units)"),
  broom::tidy(es_narrow, conf.int = TRUE) |> mutate(panel = "Narrow panel (treated + 4 controls)")
) |>
  filter(grepl("^event_time_es::", term)) |>
  mutate(period = as.integer(sub("event_time_es::", "", term))) |>
  filter(period > -100) |>
  bind_rows(tidyr::expand_grid(
    panel = c("Full panel (all units)",
              "Narrow panel (treated + 4 controls)"),
    period = -1L
  ) |> mutate(estimate = 0, conf.low = 0, conf.high = 0)) |>
  arrange(panel, period) |>
  mutate(phase = if_else(period < 0, "Pre-treatment", "Post-treatment"))

p_combo <- ggplot(es_combined, aes(x = period, y = estimate)) +
  geom_hline(yintercept = 0,    linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = -0.5, linetype = "dashed", color = "grey40") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high),
              fill = "steelblue", alpha = 0.18) +
  geom_line(color = "steelblue") +
  geom_point(aes(color = phase), size = 2.2) +
  scale_color_manual(values = c("Pre-treatment"  = "steelblue",
                                 "Post-treatment" = "firebrick")) +
  facet_wrap(~ panel, nrow = 1) +
  labs(title = "Event study: full vs. narrow controls",
       x = "Months since first treatment",
       y = "Coefficient (95% CI)", color = NULL) +
  thesis_theme()

ggsave("output/figures/event_study_combined.png", p_combo,
       width = 18, height = 5, dpi = 150)


# Extension: Bogota as control ----

# Motivation: Bogota D.C. has a pre-mesa violence slope (~+3.0 events/yr)
# much closer to the treated group's slope (~+2.9) than the narrow
# controls' slope (~+0.5). On the parallel-trends criterion alone,
# Bogota is the most-matched single control unit.
#
# Caveat: Bogota's rising trend is driven by urban-crime dynamics, not
# armed-group conflict. Parallel slopes here may be coincidental rather
# than mechanistic, so the DiD coefficient is informative but not
# theoretically clean.
#
# Bogota is now a single canonical unit_id ("bogota d.c.") after the
# consolidation step in section 1, so we no longer need to list both
# source-specific labels.

bogota_units <- c("bogota d.c.")


# 11. BOGOTA-ONLY DiD --------------------------------------------------------

panel_bogota <- panel_did[panel_did$unit_id %in% c(treated_units,
                                                     bogota_units), ]

m_bogota_active <- feols(count ~ treatment_dummy | unit_id + month_id,
                          data = panel_bogota, cluster = ~unit_id)
m_bogota_post   <- feols(count ~ post_dummy      | unit_id + month_id,
                          data = panel_bogota, cluster = ~unit_id)
screenreg(list(m_bogota_active, m_bogota_post),
          custom.model.names = c("Bogota / Active", "Bogota / Permanent"),
          stars = c(0.01, 0.05, 0.10))

es_bogota <- feols(count ~ i(event_time_es, ref = c(-1, -999)) |
                            unit_id + month_id,
                   data = panel_bogota, cluster = ~unit_id)
wald(es_bogota, keep = "^event_time_es::-(2[0-4]|1[0-9]|[2-9])$")
plot_event_study(es_bogota,
                 "Bogota-only DiD - treated vs. Bogota D.C.",
                 "output/figures/event_study_bogota.png")


# 12. (removed) Narrow + Bogota DiD ------------------------------------------
# This spec was dropped because the apparent slope match between the
# combined "narrow + Bogota" group and the treated group was an
# averaging artifact: the 4 narrow Andean controls have a flat slope
# (+0.48 events/year) while Bogota's slope alone is steep (+12/year),
# so their group-mean slope (+2.78/year) lands close to treated
# (+2.87/year) by coincidence rather than by any real shared
# trajectory. Reporting it would be misleading. The two honest
# slope-comparison candidates are reported separately above:
#   - Bogota-only DiD (section 11): closer slope to treated than the
#     narrow set, but too steep on its own.
#   - Narrow DiD (section 4): flat slope, theoretically cleaner
#     but very different from treated.
# Neither is fully comparable; this is itself the substantive finding.


# 13. Bogota pre-mesa slope (for the slope comparison narrative) -------------

bogota_trends <- panel_did |>
  filter(unit_id %in% bogota_units, month_start < first_mesa_date) |>
  group_by(month_start) |>
  summarise(mean_count = mean(count, na.rm = TRUE), .groups = "drop")

bogota_slope <- lm(mean_count ~ month_start, data = bogota_trends)
cat("Bogota pre-mesa slope (events per year): ",
    round(coef(bogota_slope)[2] * 365.25, 3),
    " (p = ", round(summary(bogota_slope)$coefficients[2, 4], 4), ")\n",
    sep = "")


# 14. Headline (all 8 specs side by side) ------------------------------------

screenreg(list(m_ref,
                m_full_active,   m_full_post,
                m_narrow_active, m_narrow_post,
                m_bogota_active, m_bogota_post,
                m_clash),
          custom.model.names = c("Main",
                                  "Full/Active",   "Full/Perm",
                                  "Narrow/Active", "Narrow/Perm",
                                  "Bogota/Active", "Bogota/Perm",
                                  "Cases+clash"),
          stars = c(0.01, 0.05, 0.10))

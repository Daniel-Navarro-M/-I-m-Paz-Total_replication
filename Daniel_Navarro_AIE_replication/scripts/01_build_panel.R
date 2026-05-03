# 01_build_panel.R
# Build the monthly Excel-based panel used throughout the current project.
#
# Study cases:
#   1. Buenaventura only
#   2. Arauca department (all municipalities in the department)
#   3. Tumaco regional cluster (Tumaco, Barbacoas, Francisco Pizarro, Roberto Payan)
#
# Data sources:
#   - ACLED monthly tables:
#       political_violence.xlsx
#       civilian_targeting.xlsx
#   - Police daily tables:
#       HOMICIDIO.xlsx
#       TERRORISMO.xlsx
#       EXTORSION.xlsx
#
# Output philosophy:
#   - One simple LONG panel for TWFE: one row per (case_id, month_id)
#   - One simple WIDE monthly table: one row per month, one total column per case

options(stringsAsFactors = FALSE)

if (!requireNamespace("readxl", quietly = TRUE)) stop("Install readxl: install.packages('readxl')")
if (!requireNamespace("writexl", quietly = TRUE)) stop("Install writexl: install.packages('writexl')")

out_dir <- "output"
processed_dir <- "data/Processed"
price_dir <- "data/Raw/prices"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Helpers
# -----------------------------------------------------------------------------

normalize_text <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  toupper(trimws(x))
}

month_lookup <- setNames(1:12, toupper(month.name))

case_ids <- c("buenaventura", "arauca", "tumaco")
case_labels <- c(
  buenaventura = "Buenaventura",
  arauca = "Arauca Department",
  tumaco = "Tumaco Region"
)

tumaco_municipalities <- c("TUMACO", "BARBACOAS", "FRANCISCO PIZARRO", "ROBERTO PAYAN")

case_from_admin <- function(admin1, admin2) {
  if (admin2 == "BUENAVENTURA") return("buenaventura")
  if (admin1 == "ARAUCA") return("arauca")
  if (admin2 %in% tumaco_municipalities) return("tumaco")
  NA_character_
}

case_from_police <- function(departamento, municipio) {
  if (municipio == "BUENAVENTURA") return("buenaventura")
  if (departamento == "ARAUCA") return("arauca")
  if (municipio %in% tumaco_municipalities) return("tumaco")
  NA_character_
}

merge_intervals <- function(s, e) {
  if (!length(s)) return(list(start = as.Date(character()), end = as.Date(character())))
  o <- order(s)
  s <- s[o]
  e <- e[o]
  i <- 1
  while (i < length(s)) {
    if (s[i + 1] <= e[i]) {
      e[i] <- max(e[i], e[i + 1])
      s <- s[-(i + 1)]
      e <- e[-(i + 1)]
    } else {
      i <- i + 1
    }
  }
  list(start = s, end = e)
}

read_period_file <- function(paths, panel_start, panel_end) {
  path <- paths[file.exists(paths)][1]
  if (is.na(path)) return(NULL)
  x <- read.csv(path, stringsAsFactors = FALSE)
  x$municipio <- trimws(tolower(x$municipio))
  x$start_date <- as.Date(x$start_date, format = "%d/%m/%Y")
  x$end_date <- as.Date(x$end_date, format = "%d/%m/%Y")
  x$start_date <- pmax(x$start_date, panel_start)
  x$end_date <- pmin(x$end_date, panel_end)
  x[!is.na(x$municipio) & !is.na(x$start_date) & !is.na(x$end_date), ]
}

apply_period_dummy <- function(panel_df, periods_df, value_name) {
  panel_df[[value_name]] <- 0L
  if (is.null(periods_df) || nrow(periods_df) == 0) return(panel_df)
  for (cid in case_ids) {
    sub <- periods_df[periods_df$municipio == cid, ]
    if (nrow(sub) == 0) next
    merged <- merge_intervals(sub$start_date, sub$end_date)
    idx <- panel_df$case_id == cid
    for (k in seq_along(merged$start)) {
      active_idx <- idx & panel_df$month_start >= merged$start[k] & panel_df$month_start <= merged$end[k]
      panel_df[[value_name]][active_idx] <- 1L
    }
  }
  panel_df
}

read_month_price <- function(path, month_col, value_col) {
  if (!file.exists(path)) return(NULL)
  x <- as.data.frame(readxl::read_excel(path))
  if (!all(c(month_col, value_col) %in% names(x))) return(NULL)
  out <- data.frame(
    month_id = as.character(x[[month_col]]),
    value = as.numeric(x[[value_col]]),
    stringsAsFactors = FALSE
  )
  out <- out[!is.na(out$month_id) & !is.na(out$value), ]
  out
}

# -----------------------------------------------------------------------------
# 2. Read ACLED monthly tables
# -----------------------------------------------------------------------------

read_acled_monthly <- function(path, event_name) {
  x <- as.data.frame(readxl::read_excel(path, sheet = 1))
  x$Admin1_std <- normalize_text(x$Admin1)
  x$Admin2_std <- normalize_text(x$Admin2)
  x$case_id <- mapply(case_from_admin, x$Admin1_std, x$Admin2_std)
  x$month_num <- unname(month_lookup[normalize_text(x$Month)])
  x$year_num <- as.integer(x$Year)
  x$month_id <- sprintf("%04d-%02d", x$year_num, x$month_num)
  x$count <- as.numeric(x$Events)
  x <- x[!is.na(x$case_id) & !is.na(x$year_num) & !is.na(x$month_num), ]
  x <- x[x$year_num >= 2018, ]
  out <- aggregate(count ~ case_id + month_id, data = x, FUN = sum, na.rm = TRUE)
  names(out)[3] <- event_name
  out
}

acled_pv   <- read_acled_monthly("data/Raw/ACLED/political_violence.xlsx", "political_violence")
acled_ct   <- read_acled_monthly("data/Raw/ACLED/civilian_targeting.xlsx", "civilian_targeting")

# -----------------------------------------------------------------------------
# 3. Read police daily tables and aggregate to month
# -----------------------------------------------------------------------------

read_police_daily <- function(path, event_name) {
  x <- as.data.frame(readxl::read_excel(path, sheet = 1))
  x$fecha <- as.Date(x[["FECHA HECHO"]])
  x$departamento_std <- normalize_text(x$DEPARTAMENTO)
  x$municipio_std <- normalize_text(x$MUNICIPIO)
  x$case_id <- mapply(case_from_police, x$departamento_std, x$municipio_std)
  x$month_id <- format(as.Date(format(x$fecha, "%Y-%m-01")), "%Y-%m")
  x$count <- as.numeric(x$CANTIDAD)
  x <- x[!is.na(x$case_id) & !is.na(x$fecha), ]
  x <- x[x$fecha >= as.Date("2018-01-01"), ]
  out <- aggregate(count ~ case_id + month_id, data = x, FUN = sum, na.rm = TRUE)
  names(out)[3] <- event_name
  out
}

pol_hom <- read_police_daily("data/Raw/POLICE/HOMICIDIO.xlsx", "homicides")
pol_ter <- read_police_daily("data/Raw/POLICE/TERRORISMO.xlsx", "terrorism")
pol_ext <- read_police_daily("data/Raw/POLICE/EXTORSION.xlsx", "extortion")

# -----------------------------------------------------------------------------
# 4. Build one balanced case × month panel
# -----------------------------------------------------------------------------

source_tables <- list(acled_pv, acled_ct, pol_hom, pol_ter, pol_ext)

all_month_ids <- unique(unlist(lapply(source_tables, function(d) d$month_id)))
all_month_ids <- all_month_ids[!is.na(all_month_ids)]
if (!length(all_month_ids)) stop("No monthly observations found in the Excel sources.")

panel_start <- as.Date("2018-01-01")
panel_end <- as.Date(paste0(max(all_month_ids), "-01"))
month_seq <- seq(panel_start, panel_end, by = "month")

panel <- expand.grid(
  case_id = case_ids,
  month_id = format(month_seq, "%Y-%m"),
  stringsAsFactors = FALSE
)
panel$month_start <- as.Date(paste0(panel$month_id, "-01"))
panel$case_label <- unname(case_labels[panel$case_id])
panel$spatial_definition <- ifelse(
  panel$case_id == "buenaventura", "Municipality only",
  ifelse(panel$case_id == "arauca", "Entire department", "Tumaco regional cluster")
)

merge_event <- function(panel_df, event_df) {
  merge(panel_df, event_df, by = c("case_id", "month_id"), all.x = TRUE, sort = FALSE)
}

panel <- merge_event(panel, acled_pv)
panel <- merge_event(panel, acled_ct)
panel <- merge_event(panel, pol_hom)
panel <- merge_event(panel, pol_ter)
panel <- merge_event(panel, pol_ext)

event_cols <- c(
  "political_violence",
  "civilian_targeting",
  "homicides",
  "terrorism",
  "extortion"
)
for (v in event_cols) panel[[v]][is.na(panel[[v]])] <- 0

panel$total_events <- rowSums(panel[, event_cols], na.rm = TRUE)

# Keep the build aggregate-only in the saved panel.
panel$source_count <- length(event_cols)

cat("\n=== Monthly panel built from Excel files ===\n")
cat("Rows:", nrow(panel), "\n")
cat("Months:", min(panel$month_id), "to", max(panel$month_id), "\n")
cat("Cases:", paste(unique(panel$case_label), collapse = ", "), "\n")
cat("\nFirst rows:\n")
print(head(panel[, c("case_id", "month_id", "total_events")]))

# -----------------------------------------------------------------------------
# 5. Treatment periods
# -----------------------------------------------------------------------------

tp_paths <- c("treatment_periods.csv", "raw/treatment_periods.csv")
tp <- read_period_file(tp_paths, panel_start, panel_end)
if (is.null(tp)) stop("treatment_periods.csv not found.")
panel <- apply_period_dummy(panel, tp, "treatment")

clash_paths <- c("clash_periods.csv", "raw/clash_periods.csv")
clash_periods <- read_period_file(clash_paths, panel_start, panel_end)
if (is.null(clash_periods)) stop("clash_periods.csv not found.")
panel <- apply_period_dummy(panel, clash_periods, "clash_dummy")

# -----------------------------------------------------------------------------
# 6. Monthly prices
# -----------------------------------------------------------------------------

panel$gold_price <- NA_real_
panel$oil_price <- NA_real_
panel$cocaine_price <- NA_real_

gold_df <- read_month_price(file.path(price_dir, "gold.xlsx"), "month", "avg_gold_price")
oil_df  <- read_month_price(file.path(price_dir, "oil.xlsx"), "month", "avg_oil_price")

if (!is.null(gold_df)) {
  panel$gold_price <- gold_df$value[match(panel$month_id, gold_df$month_id)]
}
if (!is.null(oil_df)) {
  panel$oil_price <- oil_df$value[match(panel$month_id, oil_df$month_id)]
}

cocaine_path <- file.path(price_dir, "cocaine_prices_year.xlsx")
if (file.exists(cocaine_path)) {
  coc_raw <- as.data.frame(readxl::read_excel(cocaine_path))
  if ("year" %in% names(coc_raw)) {
    price_col <- if ("avg_inflation_adjusted_2021_USD" %in% names(coc_raw)) {
      "avg_inflation_adjusted_2021_USD"
    } else {
      "avg_USD"
    }
    coc_raw <- coc_raw[!is.na(coc_raw$year) & !is.na(coc_raw[[price_col]]), ]
    coc_raw <- coc_raw[order(coc_raw$year), ]
    ref_dates <- as.numeric(as.Date(paste0(coc_raw$year, "-07-01")))
    ref_prices <- as.numeric(coc_raw[[price_col]])
    target_dates <- as.numeric(as.Date(paste0(panel$month_id, "-01")))
    panel$cocaine_price <- approx(
      x = ref_dates,
      y = ref_prices,
      xout = target_dates,
      method = "linear",
      rule = 2
    )$y
  }
}

panel$month_index <- match(panel$month_id, format(month_seq, "%Y-%m"))

panel <- panel[, c(
  "case_id", "month_id", "month_start", "case_label", "spatial_definition",
  "total_events",
  event_cols,
  "source_count", "treatment", "clash_dummy",
  "gold_price", "oil_price", "cocaine_price", "month_index"
)]

# -----------------------------------------------------------------------------
# 7. Save merged outputs
# -----------------------------------------------------------------------------

panel$case_id <- factor(panel$case_id, levels = case_ids)
panel_long <- panel[order(panel$case_id, panel$month_id), ]

wide_totals <- reshape(
  panel_long[, c("month_id", "case_id", "total_events")],
  idvar = "month_id",
  timevar = "case_id",
  direction = "wide"
)
wide_totals <- wide_totals[, c("month_id", "total_events.buenaventura", "total_events.arauca", "total_events.tumaco")]
names(wide_totals) <- c("month_id", "Buenaventura", "Arauca", "Tumaco")
wide_totals <- wide_totals[order(wide_totals$month_id), ]

long_xlsx_path <- file.path(processed_dir, "master_monthly_panel_long.xlsx")
wide_xlsx_path <- file.path(processed_dir, "master_monthly_totals_wide.xlsx")
writexl::write_xlsx(list(monthly_panel = panel_long), long_xlsx_path)
writexl::write_xlsx(list(monthly_totals = wide_totals), wide_xlsx_path)

write.csv(panel_long, file.path(processed_dir, "master_monthly_panel_long.csv"), row.names = FALSE)
write.csv(wide_totals, file.path(processed_dir, "master_monthly_totals_wide.csv"), row.names = FALSE)

saveRDS(panel_long, file.path(out_dir, "panel_monthly.rds"))
save(panel_long, file = file.path(processed_dir, "master_monthly_panel_long.RData"))

cat("\nSaved:\n")
cat("  ", long_xlsx_path, "\n")
cat("  ", wide_xlsx_path, "\n")
cat("  ", file.path(out_dir, "panel_monthly.rds"), "\n")

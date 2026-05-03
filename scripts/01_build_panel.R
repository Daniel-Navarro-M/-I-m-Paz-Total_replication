# 01_build_panel.R
# Build the monthly panel used throughout the project.
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
# Raw data can be obtained at:
# Police, homicides: https://www.datos.gov.co/Seguridad-y-Defensa/HOMICIDIO/m8fd-ahd9/about_data
# Police, terrorism: https://www.datos.gov.co/Seguridad-y-Defensa/TERRORISMO/yi5j-5fe9/about_data
# Police, Extorsion: https://www.datos.gov.co/Seguridad-y-Defensa/EXTORSI-N/q2ib-t9am/about_data

# ACLED: https://data.humdata.org/dataset/colombia-acled-conflict-data

options(stringsAsFactors = FALSE)

library(readxl)
library(writexl)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(gghighlight)
library(lubridate)

out_dir <- "output"
processed_dir <- "data/Processed"
price_dir <- "data/Raw/prices"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

# Loading the data ----

# Function that loads the datasets.And makes the transformations to have IDs and so on
# considering only events because it has no number of victims or similar.
# done like this to reduce the lines in the script and not repeat the same 
# process for all five scripts.

# column names change from ACLED and Police events. Adjust as needed

tumaco_municipalities <- c("tumaco", "barbacoas", "francisco pizarro", "roberto payan")

read_transform <- function(path, dep_col_name, mun_col_name,
                           date_col_name, count_column) {
  if (str_detect(path, ".xlsx")) {
    x <- as.data.frame(readxl::read_excel(path, sheet = 1))
  } else {
    x <- as.data.frame(read_csv(path))
  }
  
  x$fecha <- if (str_detect(path, "political|civilian")) {
    lubridate::my(paste(x$Month, x$Year))
  } else {
    as.Date(lubridate::dmy(x[[date_col_name]]))
  }
  
  x$month_id       <- format(x$fecha, "%Y-%m")
  x$departamento_std <- str_to_lower(str_squish(replace_na(as.character(x[[dep_col_name]]), "")))
  x$municipio_std    <- str_to_lower(str_squish(replace_na(as.character(x[[mun_col_name]]), "")))
  
  x$case_id <- case_when(
    x$municipio_std == "buenaventura"           ~ "buenaventura",
    x$departamento_std == "arauca"              ~ "arauca",
    x$municipio_std %in% tumaco_municipalities  ~ "tumaco",
    .default = NA_character_
  )
  
  x$count <- as.numeric(x[[count_column]])
  x <- x[!is.na(x$fecha), ]
  x[x$fecha >= as.Date("2018-01-01"), ]
}

acled_pv <- read_transform("data/Raw/ACLED/political_violence.xlsx",
                                "Admin1",
                                "Admin2",
                                NA,
                                "Events") |>
  summarise(count = sum(count, na.rm = TRUE), .by = c(case_id, month_id, departamento_std)) |>
  select(month_id, case_id, count, departamento_std) |> 
  mutate(violence_type = "political_violence")

acled_ct <- read_transform("data/Raw/ACLED/civilian_targeting.xlsx",
                 "Admin1",
                 "Admin2",
                 NA,
                 "Events") |>
  summarise(count = sum(count, na.rm = TRUE), .by = c(case_id, month_id, departamento_std)) |>
  select(month_id, case_id, count, departamento_std) |> 
  mutate(violence_type = "civilian_targeting")

pol_hom <- read_transform("data/Raw/POLICE/HOMICIDIO.csv",
                          dep_col_name  = "DEPARTAMENTO",
                          mun_col_name  = "MUNICIPIO",
                          date_col_name = "FECHA HECHO",
                          count_column  = "CANTIDAD")

# We are filtering out homicides that are not part of war and related violence.
# So we take out feminicides and homicides that are related to family issues
# or not likely related to organized crime like bar fights and so on

pol_hom <- pol_hom |>
  rename(modalidad = `MODALIDAD PRESUNTA`) |>
  filter(
    SPOA_CARACTERIZACION != "FEMINICIDIO",
    !modalidad %in% c("RIÑAS",
                      "RIÑA ENTRE COMPAÑEROS PERMANENTES",
                      "RIÑA ENTRE HERMANOS",
                      "RIÑA ENTRE HIJO-PADRE",
                      "SOFOCACION",
                      "VIOLENCIA INTRAFAMILIAR",
                      "LINCHAMIENTO",
                      "RIÑA ENTRE ESPOSOS",
                      "ATRACO")
  ) |> summarise(count = sum(count, na.rm = TRUE), .by = c(case_id, month_id, departamento_std)) |>
  select(month_id, case_id, count, departamento_std) |> 
  mutate(violence_type = "homicide")


pol_ter <- read_transform("data/Raw/POLICE/TERRORISMO.csv",
               dep_col_name  = "DEPARTAMENTO",
               mun_col_name  = "MUNICIPIO",
               date_col_name = "FECHA HECHO",
               count_column  = "CANTIDAD") |> 
  summarise(count = sum(count, na.rm = TRUE), 
            .by = c(case_id, month_id, departamento_std)) |>
  select(month_id, case_id, count, departamento_std) |> 
  mutate(violence_type = "terrorism")

pol_ext <- read_csv("data/Raw/POLICE/EXTORSION.csv", show_col_types = FALSE) |>
  mutate(`FECHA HECHO` = as.Date(lubridate::mdy(`FECHA HECHO`))) |>
  mutate(
    month_id = format(`FECHA HECHO`, "%Y-%m"),
    departamento_std = str_to_lower(str_squish(replace_na(as.character(DEPARTAMENTO), ""))),
    municipio_std = str_to_lower(str_squish(replace_na(as.character(MUNICIPIO), ""))),
    case_id = case_when(
      municipio_std == "buenaventura" ~ "buenaventura",
      departamento_std == "arauca" ~ "arauca",
      municipio_std %in% tumaco_municipalities ~ "tumaco",
      .default = NA_character_
    ),
    count = as.numeric(CANTIDAD)
  ) |>
  filter(!is.na(`FECHA HECHO`), `FECHA HECHO` >= as.Date("2018-01-01")) |> 
  summarise(count = sum(count, na.rm = TRUE), 
            .by = c(case_id, month_id, departamento_std)) |>
  select(month_id, case_id, count, departamento_std) |> 
  mutate(violence_type = "extortion")

# Build month panel ----
# case metadata
case_ids <- c("buenaventura", "arauca", "tumaco")
case_labels <- c("buenaventura" = "Buenaventura", "arauca" = "Arauca", "tumaco" = "Tumaco")
 
panel_start <- as.Date("2018-01-01")
panel_end <- as.Date(paste0(max(c(acled_pv$month_id, acled_ct$month_id, pol_hom$month_id, 
                                  pol_ter$month_id, pol_ext$month_id), na.rm = TRUE), "-01"))
month_seq <- seq(panel_start, panel_end, by = "month")

panel_long_col <- bind_rows(pol_ext, pol_hom, pol_ter, acled_pv, acled_ct) 
  
panel_long_col <- panel_long_col |> mutate(month_start = as.Date(paste0(month_id, "-01")))

# Save Colombia-long panel
write.csv(panel_long_col, file.path(processed_dir, "panel_long_col.csv"), row.names = FALSE)

## Treatment periods ----
panel_long <- panel_long_col |> filter(!is.na(case_id))

# Load and apply treatment periods
periods <- read_csv("data/raw/treatment_periods.csv")

periods <- periods |> mutate(
          municipio = str_to_lower(str_squish(municipio)),
          start_date = as.Date(start_date, format = "%d/%m/%Y"),
          end_date = as.Date(end_date, format = "%d/%m/%Y"),
          start_date = pmax(start_date, panel_start),
          end_date = pmin(end_date, panel_end))

# Load and apply clash periods
clash_periods <- read_csv("data/raw/clash_periods.csv")

clash_periods <- clash_periods |> mutate(
  municipio = str_to_lower(str_squish(municipio)),
  start_date = as.Date(start_date, format = "%d/%m/%Y"),
  end_date = as.Date(end_date, format = "%d/%m/%Y"),
  start_date = pmax(start_date, panel_start),
  end_date = pmin(end_date, panel_end))


panel_long <- panel_long |>
  mutate(
    treatment_dummy = 0L,
    clash_dummy = 0L
  )
## adding treatment dummy ----
for (i in seq_len(nrow(periods))) {
  cid <- periods$municipio[i]
  
  panel_long$treatment_dummy[
    panel_long$case_id == cid &
      panel_long$month_start >= periods$start_date[i] &
      panel_long$month_start <= periods$end_date[i]
  ] <- 1L
}

## adding clash dummy ----

for (i in seq_len(nrow(clash_periods))) {
  cid <- clash_periods$municipio[i]
  
  panel_long$clash_dummy[
    panel_long$case_id == cid &
      panel_long$month_start >= clash_periods$start_date[i] &
      panel_long$month_start <= clash_periods$end_date[i]
  ] <- 1L
}

# Save outputs ----
write.csv(panel_long, file.path(processed_dir, "panel_long.csv"), row.names = FALSE)
save(panel_long, file = file.path(processed_dir, "panel_long.RData"))

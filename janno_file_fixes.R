# random janno file correction operations

#### 1 ####
# code to fix a recently introduce janno column issue by loading an old data version and merging the old values back into the new files

# from: "https://raw.githubusercontent.com/poseidon-framework/data_ancient/1bd3922acfb25e41bce3eb8bc5eb5198830bc798/prior2018_Boston_Datashare_published/all_ancients.janno"
old_boston_datashare_janno <- readr::read_tsv(
  "~/Downloads/boston.janno",
  col_types = readr::cols(.default = readr::col_character())
)

boston_labnr <- old_boston_datashare_janno |> dplyr::select(Individual_ID, Date_C14_Labnr)

janno_files_paths <- poseidonR:::get_janno_file_paths("~/agora/published_data")

for (i in seq_along(janno_files_paths)) {
  
  cur_janno_path <- janno_files_paths[i]
  
  cur_janno <- readr::read_tsv(
    cur_janno_path,
    col_types = readr::cols(.default = readr::col_character())
  )
  
  if (!all(cur_janno$Date_C14_Labnr == cur_janno$Date_C14_Uncal_BP)) {
    next
  }
  
  fixed_janno <- cur_janno |>
    dplyr::select(-Date_C14_Labnr) |>
    dplyr::left_join(
      boston_labnr,
      by = "Individual_ID"
    ) |>
    dplyr::relocate(
      Date_C14_Labnr,
      .after = Longitude
    ) |>
    dplyr::mutate(
      Date_C14_Labnr = tidyr::replace_na(Date_C14_Labnr, "n/a")
    )
  
  readr::write_tsv(fixed_janno, file =  cur_janno_path)

}

#### 2 ####

library(magrittr)

olalde_poseidon <- readr::read_tsv(
  "~/agora/published_data/2019_Olalde_Iberia/Olalde_Iberia.janno",
  col_types = readr::cols(.default = readr::col_character())
)

olalde_paper_S1 <- readxl::read_excel(
  "~/Downloads/aav4040_TablesS1-S5.xlsx",
  sheet = 1,
  skip = 1
)

# olalde_paper_S2 <- readxl::read_excel(
#   "~/Downloads/aav4040_TablesS1-S5.xlsx",
#   sheet = 2,
#   skip = 1
# )

olalde_paper <- olalde_paper_S1 %>%
  # dplyr::left_join(
  #   olalde_paper_S2,
  #   by = c("Ind ID (_d, only sequences with aDNA damage were used for analysis)" = "Ind ID")
  # ) %>%
  # dplyr::group_by(`Library ID`) %>%
  # dplyr::filter(
  #   `number of autosomal 1240K targets hit at least one` == max(`number of autosomal 1240K targets hit at least one`) 
  # ) %>%
  # dplyr::ungroup() %>%
  dplyr::select(
    "Individual_ID_short" = "Ind ID (_d, only sequences with aDNA damage were used for analysis)",
    "Collection_ID" = "Colaborator ID",
    "Source_Tissue" = "Skeletal element",
    "UDG" = "UDG treatment for each library",
    "Genetic_Sex" = "Genetic sex",
    "MT_Haplogroup" = "mtDNA",
    "Y_Haplogroup" = "Y-chr",
    "Date_BC_AD_Median" = "Date (Direct radiocarbon date on the individual calibrated at 2 sigma or date range based on the archaeological context)",
    "Location" = "Site",
    "Latitude",
    "Longitude",
    "Country"#,
    #"Coverage_1240K" = "1240K coverage on targeted positions",
    #"Nr_autosomal_SNPs" = "number of autosomal 1240K targets hit at least one"
  ) %>%
  dplyr::mutate(
    Latitude = round(Latitude, 5),
    Longitude = round(Longitude, 5)
  )

olalde_both <- olalde_poseidon %>%
  dplyr::mutate(
    Individual_ID_short = gsub("_published", "", Individual_ID)
  ) %>%
  dplyr::left_join(
    olalde_paper,
    by = "Individual_ID_short",
    suffix = c(".poseidon", ".paper")
  )# %>% 
  #dplyr::select("Individual_ID", sort(colnames(.)))
  
olalde_both %>%
  readr::write_tsv(
    "~/agora/published_data/2019_Olalde_Iberia/Olalde_Iberia.janno2",
    na = "n/a"
  )

#### 3 ####

# parse dating column

library(magrittr)

olalde_poseidon <- readr::read_tsv(
  "~/agora/published_data/2019_Olalde_Iberia/Olalde_Iberia.janno",
  col_types = readr::cols(.default = readr::col_character())
)

age_string_split <- split_age_string(olalde_poseidon$Date_BC_AD_Median.paper)

cal_res <- poseidonR::quickcalibrate(
  Map(as.numeric, strsplit(age_string_split$Date_C14_Uncal_BP, ";")),
  Map(as.numeric, strsplit(age_string_split$Date_C14_Uncal_BP_Err, ";"))
)

res <- cbind(
  age_string_split[1:4],
  cal_res[1],
  age_string_split[5:7]
)

res$Date_BC_AD_Start[res$Date_Type == "C14"] <- cal_res$Date_BC_AD_Start[res$Date_Type == "C14"]
res$Date_BC_AD_Stop[res$Date_Type == "C14"] <- cal_res$Date_BC_AD_Stop[res$Date_Type == "C14"]
res$Date_BC_AD_Median[res$Date_Type == "contextual"] <- purrr::map2_int(
  res$Date_BC_AD_Start[res$Date_Type == "contextual"],
  res$Date_BC_AD_Stop[res$Date_Type == "contextual"],
  function(x, y) { as.integer(round(mean(c(x,y)))) }
)

readr::write_tsv(res, "~/agora/published_data/2019_Olalde_Iberia/dating.tsv", na = "n/a")

split_age_string <- function(x) {
  
  # construct result table
  res <- tibble::tibble(
    x = x,
    Date_C14_Labnr = rep(NA, length(x)),
    Date_C14_Uncal_BP = NA,
    Date_C14_Uncal_BP_Err = NA,
    Date_BC_AD_Start = NA,
    Date_BC_AD_Stop = NA,
    Date_Type = NA
  )
  
  # determine type of date info
  none_ids <- which(is.na(x))
  present_ids <- grep("present", x)
  c14_age_ids <- grep("±", x)
  res$Date_Type[c14_age_ids] <- "C14"
  res$Date_Type[-c14_age_ids] <- "contextual"
  res$Date_Type[present_ids] <- "modern"
  res$Date_Type[none_ids] <- "none"
  
  # parse uncalibrated c14 age info
  res$Date_C14_Labnr[c14_age_ids] <- stringr::str_extract_all(
    x[c14_age_ids], paste(
      c(
        "CNA-?[0-9]*",
        # "AAR-\\s[0-9]*",
        # "OxA-X-[0-9]*-[0-9]*",
        # "CIRCE-DSH-[0-9]*",
        # "ISGS-A[0-9]*",
        # "CEDAD-LTL[0-9]*A",
        "[A-Za-z]{2,7}-[0-9]*"
      ),
      collapse = "|"
    )
  ) %>% sapply(., function(y) { paste(y, collapse = ";") } )
  uncal_dates <- stringr::str_extract_all(x[c14_age_ids], "[0-9]{1,5}\u00B1[0-9]{1,4}")
  res$Date_C14_Uncal_BP[c14_age_ids] <- sapply(uncal_dates, function(z) { 
    sapply(strsplit(z, "\u00B1"), function(a) { a[1] } ) %>% 
      paste(collapse = ";") 
  } )
  res$Date_C14_Uncal_BP_Err[c14_age_ids] <- sapply(uncal_dates, function(z) { 
    sapply(strsplit(z, "\u00B1"), function(a) { a[2] } ) %>% 
      paste(collapse = ";") 
  } )
  
  # parse simplified start and stop age
  simple_age_split <- x %>% strsplit("–|\\s+") %>% lapply(function(y) {y[y != ""]})
  stop <- start <- rep(NA, length(simple_age_split))
  for (i in 1:length(simple_age_split)) {
    # no age info
    if (is.na(simple_age_split[[i]][1]) | simple_age_split[[i]][1] == "n/a") {
      start[i] <- NA
      stop[i] <- NA
      next
    }
    # no range: only one value e.g. 5000 BCE
    if (length(simple_age_split[[i]]) == 2) {
      if (simple_age_split[[i]][2] == "BCE" |
          (simple_age_split[[i]][2] == "cal" & simple_age_split[[i]][2] == "BCE")) {
        start[i] <- -as.numeric(simple_age_split[[i]][1])
        stop[i] <- -as.numeric(simple_age_split[[i]][1])
        next
      }
      if (simple_age_split[[i]][2] == "CE" |
          (simple_age_split[[i]][2] == "cal" & simple_age_split[[i]][2] == "CE")) {
        start[i] <- as.numeric(simple_age_split[[i]][1])
        stop[i] <- as.numeric(simple_age_split[[i]][1])
        next
      } 
      if (all(grepl("^[0-9]+$", simple_age_split[[i]]))) {
        start[i] <- -as.numeric(simple_age_split[[i]][1])
        stop[i] <- -as.numeric(simple_age_split[[i]][2])
        next
      }
    }
    # normal range 5000-4700 BCE
    if (simple_age_split[[i]][2] == "cal" &
        simple_age_split[[i]][3] == "BCE" &
        simple_age_split[[i]][5] == "cal" &
        simple_age_split[[i]][6] == "CE") {
      start[i] <- -as.numeric(simple_age_split[[i]][1])
      stop[i] <- as.numeric(simple_age_split[[i]][4])
      next
    }
    if (simple_age_split[[i]][3] %in% c("BCE", "calBCE") |
        (simple_age_split[[i]][3] == "cal" & simple_age_split[[i]][4] == "BCE")) {
      start[i] <- -as.numeric(simple_age_split[[i]][1])
      stop[i] <- -as.numeric(simple_age_split[[i]][2])
      next
    }
    if (simple_age_split[[i]][3] %in% c("CE", "calCE") |
        (simple_age_split[[i]][3] == "cal" & simple_age_split[[i]][4] == "CE")) {
      start[i] <- as.numeric(simple_age_split[[i]][1])
      stop[i] <- as.numeric(simple_age_split[[i]][2])
      next
    }
    if (simple_age_split[[i]][2] %in% c("BCE", "calBCE") & 
        simple_age_split[[i]][4] %in% c("CE", "calCE")) {
      start[i] <- -as.numeric(simple_age_split[[i]][1])
      stop[i] <- as.numeric(simple_age_split[[i]][3])
      next
    }
  }
  
  res$Date_BC_AD_Start <- start
  res$Date_BC_AD_Stop <- stop
  
  # replace all empty values with NA
  res[res == ""] <- NA
  
  return(res)
}





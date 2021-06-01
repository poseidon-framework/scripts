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










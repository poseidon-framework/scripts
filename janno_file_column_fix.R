# script to fix a recently introduce janno column issue by loading an old data version and merging the old values back into the new files

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


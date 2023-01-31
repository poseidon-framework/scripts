con <- sidora.core::get_pandora_connection(".credentials")

tab_raw <- get_df("TAB_Raw_Data", con)

samples_and_dois <- tab_raw %>%
  dplyr::select(raw_data.Full_Raw_Data_Id, raw_data.DOI) %>%
  dplyr::filter(raw_data.DOI != "") %>%
  dplyr::transmute(
    sample_id = purrr::map_chr(strsplit(raw_data.Full_Raw_Data_Id, "\\."), \(x) x[1]),
    doi = gsub("https://doi.org/", "", raw_data.DOI) %>% trimws
  ) %>%
  unique

my_doi <- "10.1073/pnas.1820447116"

samples_with_my_doi <- samples_and_dois %>%
  dplyr::filter(doi == my_doi)

forge_file_entries <- samples_with_my_doi$sample_id %>%
  paste0("<", . , ">")

writeLines(forge_file_entries, "forge_file.txt")

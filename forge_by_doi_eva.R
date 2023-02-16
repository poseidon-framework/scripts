library(sidora.core)
library(dplyr)

con <- get_pandora_connection("~/.credentials")

tab_raw <- get_df("TAB_Raw_Data", con)

doi_package_table <- tibble::tribble(
  ~package_name, ~doi,
  "2018_Lamnidis_Fennoscandia", "10.1038/s41467-018-07483-5", 
  "2019_Villalba_Iberia", "10.1016/j.cub.2019.02.006", 
  "2020_BarqueraCurrentBiology", "10.1016/j.cub.2020.04.002", 
  "2020_Furtwaengler_Switzerland", "10.1038/s41467-020-15560-x", 
  "2020_Nagele_Caribbean", "10.1126/science.aba8697", 
  "2020_Rivollat_FranceGermany", "10.1126/sciadv.aaz5344", 
  "2020_Skourtanioti_NearEast", "10.1016/j.cell.2020.04.044", 
  "2021_CarlhoffNature", "10.1038/s41586-021-03823-6", 
  "2021_GnecchiRuscone_KazakhSteppe", "10.1126/sciadv.abe4414", 
  "2021_Papac_CentralEurope", "10.1126/sciadv.abi6941", 
  "2022_GnecchiRuscone_Avar", "10.1016/j.cell.2022.03.007", 
  "2022_Gretzinger_AngloSaxon", "10.1038/s41586-022-05247-2 ", 
  "2022_Childebayeva_Derenburg", "10.1093/molbev/msac108"
)

samples_and_dois <- tab_raw %>%
  select(raw_data.Full_Raw_Data_Id, raw_data.DOI) %>%
  filter(raw_data.DOI != "") %>%
  transmute(
    sample_id = purrr::map_chr(strsplit(raw_data.Full_Raw_Data_Id, "\\."), \(x) x[1]),
    doi = gsub("https://doi.org/", "", raw_data.DOI) %>% trimws
  ) %>%
  unique %>%
  inner_join(doi_package_table)

packages <- samples_and_dois %>% pull(package_name) %>% unique()

for(pac in packages) {
  samples_and_dois %>%
    filter(package_name == pac) %>%
    pull(sample_id) %>%
    paste0("<", . , ">") %>%
    sort() %>%
    writeLines(paste0("/mnt/archgen/poseidon/Pandora_forges/", pac, ".forge_file.txt"))
}

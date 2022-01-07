setwd("~/agora/published_data")

jannoFile <- list.files(pattern = ".janno", recursive = T)[3]

jannoDF <- readr::read_tsv(jannoFile)

# remove columns with only empty values
jannoDFwithoutNA <- jannoDF |>
  dplyr::select(tidyselect:::where(\(x) {!all(x == "n/a" | x == "")}))

# simple column renaming
colNameLookup <- hash::hash(
  c("Individual_ID", "No_of_Libraries", "Data_Type", "Nr_autosomal_SNPs", "Publication_Status", "Coverage_1240K"),
  c("Poseidon_ID", "Nr_Libraries", "Capture_Type", "Nr_SNPs", "Publication", "Coverage_on_Target_SNPs")
)

replaceName <- function(x) {
  if (x %in% hash::keys(colNameLookup)) {
    hash::values(colNameLookup, x)
  } else {
    x
  }
}

colnames(jannoDFwithoutNA) <- sapply(colnames(jannoDFwithoutNA), replaceName)

# enable new contamination meas setup
# ...

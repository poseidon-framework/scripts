#### get column order data ####

columnOrder <- readr::read_tsv("https://raw.githubusercontent.com/poseidon-framework/poseidon2-schema/janno_column_names_and_order/janno_columns.tsv")$janno_column_name

#### helper functions ####

isPoseidonNA <- function(x) {
  all(is.na(x) | x == "n/a" | x == "")
}

uniteWithoutNA <- function(x, y, toUniteFirst = x, toUniteSecond = y) {
  purrr::pmap_chr(
    list(x, y, toUniteFirst, toUniteSecond), \(a, b, tF, tS) {
      if (isPoseidonNA(a) & isPoseidonNA(b)) {
        "n/a"
      } else if (isPoseidonNA(a) & !isPoseidonNA(b)) {
        paste(tS)
      } else if (!isPoseidonNA(a) & isPoseidonNA(b)) {
        paste(tF)
      } else {
        paste(tF, tS, sep = ";")
      }
    }
  )
}

colNameLookup <- hash::hash(
  c("Individual_ID", "No_of_Libraries", "Data_Type", "Nr_autosomal_SNPs", "Publication_Status", "Coverage_1240K"),
  c("Poseidon_ID", "Nr_Libraries", "Capture_Type", "Nr_SNPs", "Publication", "Coverage_on_Target_SNPs")
)

lookupName <- function(x) {
  if (x %in% hash::keys(colNameLookup)) {
    hash::values(colNameLookup, x)
  } else {
    x
  }
}

constructNewContamCols <- function(janno) {
  # start by adding empty (old) contam columns, if they are missing (technically more simple)
  if (!"Xcontam" %in% colnames(janno)) {
    janno$Xcontam <- "n/a"
    janno$Xcontam_stderr <- "n/a"
  }
  if (!"mtContam" %in% colnames(janno)) {
    janno$mtContam <- "n/a"
    janno$mtContam_stderr <- "n/a"
  }
  
  # construct new contam columns from the old ones
  janno |>
    dplyr::select(Poseidon_ID, Xcontam, Xcontam_stderr, mtContam, mtContam_stderr) |>
    dplyr::transmute(
      Contamination = uniteWithoutNA(Xcontam, mtContam),
      Contamination_Err = uniteWithoutNA(Xcontam, mtContam, Xcontam_stderr, mtContam_stderr),
      Contamination_Meas = uniteWithoutNA(Xcontam, mtContam, "X-based (unknown software)", "mt-based (unknown software)")
    )
}

updateJanno <- function(janno) {
  
  # simple column renaming
  jannoNewColNames <- janno
  colnames(jannoNewColNames) <- sapply(colnames(jannoNewColNames), lookupName)
  
  # enable new contamination column setup
  jannoContam <- dplyr::bind_cols(jannoNewColNames, constructNewContamCols(jannoNewColNames))
  
  # remove columns with only empty values
  jannoWithoutNA <- jannoContam |>
    dplyr::select(tidyselect:::where(\(x) { !isPoseidonNA(x) }))
  
  # reorder columns
  jannoReordered <- jannoWithoutNA[columnOrder[columnOrder %in% colnames(jannoWithoutNA)]]
  
  # return list with file name and 
  return(list(jannoFile, jannoReordered))
}

#### update one janno file ####

jannoFile <- "path/to/your/janno/file.janno"
janno <- readr::read_tsv(jannoFile, show_col_types = FALSE)
updatedJanno <- updateJanno(janno)
readr::write_tsv(updatedJanno[[2]], file = updatedJanno[[1]], na = "n/a")

#### update multiple janno files ####

# find all janno files
jannoFiles <- list.files("~/agora/published_data", pattern = ".janno", recursive = T, full.names = T)

# write files back to file system
result_janno_list <- purrr::walk(
  jannoFiles, function(jannoFile) {
    janno <- readr::read_tsv(jannoFile, show_col_types = FALSE)
    updatedJanno <- updateJanno(janno)
    readr::write_tsv(updatedJanno[[2]], file = updatedJanno[[1]], na = "n/a")
  }
)

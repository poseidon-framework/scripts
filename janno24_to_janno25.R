setwd("~/agora/published_data")

columnOrder <- readr::read_tsv("https://raw.githubusercontent.com/poseidon-framework/poseidon2-schema/janno_column_names_and_order/janno_columns.tsv")$janno_column_name

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

replaceName <- function(x) {
  if (x %in% hash::keys(colNameLookup)) {
    hash::values(colNameLookup, x)
  } else {
    x
  }
}

jannoFiles <- list.files(pattern = ".janno", recursive = T)
purrr::map(
  jannoFiles, function(jannoFile) {
    
    jannoDF <- readr::read_tsv(jannoFile, show_col_types = FALSE)
    
    # simple column renaming
    jannoDFnewColNames <- jannoDF
    colnames(jannoDFnewColNames) <- sapply(colnames(jannoDFnewColNames), replaceName)
    
    # enable new contamination meas setup
    # add empty contam columns, if they are missing (technically more simple)
    if (!"Xcontam" %in% colnames(jannoDFnewColNames)) {
      jannoDFnewColNames$Xcontam <- "n/a"
      jannoDFnewColNames$Xcontam_stderr <- "n/a"
    }
    if (!"mtContam" %in% colnames(jannoDFnewColNames)) {
      jannoDFnewColNames$mtContam <- "n/a"
      jannoDFnewColNames$mtContam_stderr <- "n/a"
    }
    
    contam <- jannoDFnewColNames |>
      dplyr::select(Poseidon_ID, Xcontam, Xcontam_stderr, mtContam, mtContam_stderr) |>
      dplyr::transmute(
        Contamination = uniteWithoutNA(Xcontam, mtContam),
        Contamination_Err = uniteWithoutNA(Xcontam, mtContam, Xcontam_stderr, mtContam_stderr),
        Contamination_Meas = uniteWithoutNA(Xcontam, mtContam, "X-based (unknown software)", "mt-based (unknown software)")
      )
    
    jannoContam <- jannoDFnewColNames |>
      dplyr::select(-Xcontam, -Xcontam_stderr, -mtContam, -mtContam_stderr) |>
      dplyr::bind_cols(contam)
    
    # remove columns with only empty values
    jannoDFwithoutNA <- jannoContam |>
      dplyr::select(tidyselect:::where(\(x) {!isPoseidonNA(x)}))
    
    # reorder columns
    jannoReordered <- jannoDFwithoutNA[columnOrder[columnOrder %in% colnames(jannoDFwithoutNA)]]
    
    return(list(jannoFile, jannoReordered))
  }
) -> result_janno_list

# write files back to file system
purrr::walk(
  result_janno_list, function(x) {
    readr::write_tsv(x[[2]], file = x[[1]], na = "n/a")
  }
)


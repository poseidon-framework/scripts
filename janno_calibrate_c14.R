#!/usr/bin/env Rscript

# janno_calibrate_c14.R
## This script is used to calibrate the C14 dates in an input janno file.
## A new janno is created with filled Date_BC_AD_Start, Date_BC_AD_Median, and Date_BC_AD_Stop based on
## the information provided in the Date_C14_Uncal_BP and Date_C14_Uncal_BP_Err columns.
## Unless specifically requested, the script does NOT overwrite values in the output columns.

# Usage: janno_calibrate_c14.R <input_janno_file> <output_janno_file>

suppressPackageStartupMessages(require(optparse))
suppressPackageStartupMessages(require(dplyr, warn.conflicts = FALSE))
suppressPackageStartupMessages(require(magrittr))
if(!require('remotes', quietly = T)) install.packages('remotes')
if(!require('janno', quietly = T)) remotes::install_github('poseidon-framework/janno')

VERSION <- "1.0.0"

option_list <- list(
  make_option(c("-i", "--input") , type = "character", help = "Path to the input poseidon package directory" , metavar = "Pacakge_Dir"),
  make_option(c("-o", "--output"), type = "character", help = "Path to the output janno file", metavar = "new_janno"),
  make_option(c("-w", "--overwrite_existing"), action = "store_true", default = FALSE, 
              help = "Overwrite existing values in the output columns. When this option is provided, newly-computed values will be preferred over existing ones. The original values will be kept for any fields that are not inferred. (default: FALSE)"),
  make_option(c("-v", "--version"), action = "store_true", default = FALSE, 
              help = "Print the script version and exit")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

if (opt$version) {
  cat("janno_calibrate_c14.R version", VERSION, "\n")
  quit(status = 0)
}

if (is.null(opt$input) || is.null(opt$output)) {
  print_help(opt_parser)
  stop("Both input and output janno files must be specified.", call. = FALSE)
}

## Load the input janno file
message("Reading input janno")
input_janno <- suppressMessages(janno::read_janno(opt$input))

## Check if the required columns are present
required_columns <- c("Latitude", "Date_Type", "Date_C14_Labnr", "Date_C14_Uncal_BP", "Date_C14_Uncal_BP_Err", 
                      "Date_BC_AD_Start", "Date_BC_AD_Median",
                      "Date_BC_AD_Stop", "Date_Note")

missing_columns <- setdiff(required_columns, colnames(input_janno))
## If any required columns are missing, add them as NA
if (length(missing_columns) > 0) {
  input_janno[missing_columns] <- NA
}

## Northern Hemisphere
if ( nrow( filter(input_janno, Latitude >= 0, ! is.na(Date_Type) > 1)) ) {
  message("Calibrating dates in Northern Hemisphere")
  calibrated_north <- input_janno %>%
    dplyr::filter( Latitude >= 0, ! is.na(Date_Type) ) %>%
    janno::process_age(
      choices   = c("Date_BC_AD_Prob", "Date_BC_AD_Start_Derived", "Date_BC_AD_Median_Derived", "Date_BC_AD_Stop_Derived"),
      cal_curve = "intcal20"
    ) %>%
    dplyr::mutate(
      Date_Note_Derived = dplyr::case_when(
        Date_Type == "C14" ~ paste0("IntCal20, calibrated with janno R package: ", packageVersion("janno")),
        TRUE               ~ Date_Note
      )
    )
} else {calibrated_north <- NULL}

## Southern Hemisphere calibration curve
if ( nrow( filter(input_janno, Latitude < 0, ! is.na(Date_Type) > 1)) ) {
  message("Calibrating dates in Southern Hemisphere")
  calibrated_south <- input_janno %>% 
    dplyr::filter( Latitude < 0, ! is.na(Date_Type) ) %>%
    janno::process_age(
      choices   = c("Date_BC_AD_Prob", "Date_BC_AD_Start_Derived", "Date_BC_AD_Median_Derived", "Date_BC_AD_Stop_Derived"),
      cal_curve = "shcal20"
    ) %>%
    dplyr::mutate(
      Date_Note_Derived = dplyr::case_when(
        Date_Type == "C14" ~ paste0("SHCal20, calibrated with janno R package: ", packageVersion("janno")),
        TRUE               ~ Date_Note
      )
    )
} else {calibrated_south <- NULL}

calibrated_dates <- bind_rows(
  calibrated_north,
  calibrated_south,
  dplyr::filter(input_janno, is.na(Date_Type))
) %>%
  dplyr::select(Poseidon_ID, ends_with("_Derived"), -Date_BC_AD_Prob) %>%
  dplyr::rename(
    .cols = ends_with("_Derived"),
    Date_BC_AD_Stop   = Date_BC_AD_Stop_Derived,
    Date_BC_AD_Median = Date_BC_AD_Median_Derived,
    Date_BC_AD_Start  = Date_BC_AD_Start_Derived,
    Date_Note         = Date_Note_Derived
  )

## Prepare output janno, according to overwrite_existing
message("Generating output janno")
joined_janno <- input_janno %>%
  left_join(calibrated_dates, by="Poseidon_ID")

if ( ! opt$overwrite_existing ) {
  output_janno <- joined_janno %>%
    dplyr::mutate(
      .keep = "unused", 
      Date_BC_AD_Stop   = dplyr::coalesce(Date_BC_AD_Stop.x,   Date_BC_AD_Stop.y   ),
      Date_BC_AD_Median = dplyr::coalesce(Date_BC_AD_Median.x, Date_BC_AD_Median.y ),
      Date_BC_AD_Start  = dplyr::coalesce(Date_BC_AD_Start.x,  Date_BC_AD_Start.y  ),
      Date_Note         = dplyr::case_when(
        is.na(Date_Note.x) ~ Date_Note.y,
        is.na(Date_Note.y) ~ Date_Note.x,
        TRUE               ~ paste(Date_Note.x, Date_Note.y, sep=';')
      )
    )
} else {
  output_janno <- joined_janno %>%
    dplyr::mutate(
      .keep = "unused", 
      Date_BC_AD_Stop   = dplyr::coalesce(Date_BC_AD_Stop.y,   Date_BC_AD_Stop.x   ),
      Date_BC_AD_Median = dplyr::coalesce(Date_BC_AD_Median.y, Date_BC_AD_Median.x ),
      Date_BC_AD_Start  = dplyr::coalesce(Date_BC_AD_Start.y,  Date_BC_AD_Start.x  ),
      Date_Note         = dplyr::case_when(
        is.na(Date_Note.x) ~ Date_Note.y,
        is.na(Date_Note.y) ~ Date_Note.x,
        TRUE               ~ paste(Date_Note.y, Date_Note.x, sep=';')
      )
    )
}

message("Writing janno to file ", opt$output)
janno::write_janno(output_janno, opt$output)

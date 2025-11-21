# R/_helpers_extract.R
# Common helpers (paths, safe readers, small utilities)
# Used by extraction and reporting scripts

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(broom)
  library(broom.mixed)
})

dir.create("output/publish", recursive = TRUE, showWarnings = FALSE)

# ---------- Paths ----------
DATA_PATH <- "data/analysis_ready/bap_ddm_ready.csv"
MODEL_PATH <- "output/publish/fit_primary_vza.rds"    # change if using another fit
LOO_PATH   <- "output/publish/loo_difficulty_all.csv"

PPC_MAIN   <- "output/publish/table3_ppc_primary_pooled.csv"
PPC_COND   <- "output/publish/table3_ppc_primary_conditional.csv"
PPC_UNCOND <- "output/publish/table3_ppc_primary_unconditional.csv"

# ---------- Safe readers ----------
safe_read_csv <- function(path) {
  if (!file.exists(path)) stop("Missing file: ", path)
  read_csv(path, show_col_types = FALSE)
}

write_clean <- function(df, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  write_csv(df, path)
  message("✓ wrote: ", path)
}

# ---------- Data helpers ----------
# Small accuracy helper if not present
ensure_decision <- function(dd) {
  if (!"decision" %in% names(dd)) {
    cand <- c("correct", "iscorr", "is_correct", "accuracy", "acc")
    have <- cand[cand %in% names(dd)]
    if (length(have)) {
      dd$decision <- as.integer(dd[[have[1]]])
    } else {
      stop("No 'decision' or correctness field found.")
    }
  }
  dd$decision <- as.integer(dd$decision)
  dd
}


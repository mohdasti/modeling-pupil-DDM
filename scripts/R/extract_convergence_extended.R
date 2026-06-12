#!/usr/bin/env Rscript
# Extract bulk/tail ESS and max R-hat for primary + interaction models.
#
# Usage:
#   DDM_RUN_ID=20260226_092110 Rscript scripts/R/extract_convergence_extended.R
#
# Output:
#   output/ddm_refits/runs/<RUN_ID>/tables/convergence_primary_extended.csv

suppressPackageStartupMessages({
  library(brms)
  library(dplyr)
  library(readr)
  library(here)
  library(tibble)
})

RUN_ID <- Sys.getenv("DDM_RUN_ID", "20260226_092110")
ROOT <- here::here()
RUN_DIR <- file.path(ROOT, "output", "ddm_refits", "runs", RUN_ID)
MODELS_DIR <- file.path(RUN_DIR, "models")
TABLES_DIR <- file.path(RUN_DIR, "tables")
dir.create(TABLES_DIR, recursive = TRUE, showWarnings = FALSE)

extract_ess <- function(fit) {
  s <- summary(fit)
  tail_ess <- c(s$fixed$Tail_ESS)
  bulk_ess <- c(s$fixed$Bulk_ESS)
  if (!is.null(s$random)) {
    for (nm in names(s$random)) {
      tail_ess <- c(tail_ess, s$random[[nm]]$Tail_ESS)
      bulk_ess <- c(bulk_ess, s$random[[nm]]$Bulk_ESS)
    }
  }
  tail_ess <- tail_ess[is.finite(tail_ess)]
  bulk_ess <- bulk_ess[is.finite(bulk_ess)]
  list(
    min_tail_ess = if (length(tail_ess)) min(tail_ess) else NA_real_,
    min_bulk_ess = if (length(bulk_ess)) min(bulk_ess) else NA_real_,
    max_rhat = max(rhat(fit), na.rm = TRUE)
  )
}

rows <- list()
add_row <- function(model_label, path) {
  if (!file.exists(path)) return(invisible(NULL))
  fit <- readRDS(path)
  ess <- extract_ess(fit)
  div <- tryCatch({
    nuts <- nuts_params(fit)
    sum(nuts$Parameter == "divergent__" & nuts$Value == 1, na.rm = TRUE)
  }, error = function(e) NA_integer_)
  rows[[length(rows) + 1L]] <<- tibble(
    model = model_label,
    rds_path = basename(path),
    max_rhat = ess$max_rhat,
    min_bulk_ess = ess$min_bulk_ess,
    min_tail_ess = ess$min_tail_ess,
    divergences = div
  )
}

add_row(
  "additive_primary",
  file.path(MODELS_DIR, "additive__probe_onset_locked__thr0.20.rds")
)
add_row(
  "interaction_primary",
  file.path(MODELS_DIR, "interaction__probe_onset_locked__thr0.20.rds")
)

out <- bind_rows(rows)
out_path <- file.path(TABLES_DIR, "convergence_primary_extended.csv")
write_csv(out, out_path)
cat("Wrote:", out_path, "\n")
print(out)

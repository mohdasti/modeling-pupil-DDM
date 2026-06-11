#!/usr/bin/env Rscript
# Merge pupil LOO tables: primary nested models, truncated window, Cavanagh boundary.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(here)
})

ROOT <- here::here()

read_loo <- function(path, tag) {
  if (!file.exists(path)) return(NULL)
  read_csv(path, show_col_types = FALSE) %>% mutate(source_tag = tag)
}

parts <- list(
  read_loo(file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_summary.csv"), "primary_w3"),
  read_loo(file.path(ROOT, "output", "ddm_pupil_w1p3", "tables", "pupil_loo_summary.csv"), "truncated_w1p3"),
  read_loo(file.path(ROOT, "output", "ddm_pupil_boundary", "tables", "pupil_boundary_loo_summary.csv"), "cavanagh_bs_primary"),
  read_loo(file.path(ROOT, "output", "ddm_pupil_boundary_w1p3", "tables", "pupil_boundary_loo_summary.csv"), "cavanagh_bs_truncated")
)

parts <- Filter(Negate(is.null), parts)
if (length(parts) == 0) stop("No pupil LOO CSVs found.")

combined <- bind_rows(parts)

out_all <- file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_all_models.csv")
write_csv(combined, out_all)

# Window comparison (m0–m3 only, side by side)
w3 <- read_loo(file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_summary.csv"), "w3_primary")
w1 <- read_loo(file.path(ROOT, "output", "ddm_pupil_w1p3", "tables", "pupil_loo_summary.csv"), "w1p3_truncated")
if (!is.null(w3) && !is.null(w1)) {
  w3 <- w3 %>% mutate(tepr_window = "Decision-Response AUC (0.3–3.3 s post-probe)")
  w1 <- w1 %>% mutate(tepr_window = "Truncated Decision-Response AUC (0.3–1.3 s post-probe)")
  out_cmp <- file.path(ROOT, "output", "ddm_pupil", "tables", "pupil_loo_window_comparison.csv")
  write_csv(bind_rows(w3, w1), out_cmp)
  message("Wrote ", out_cmp)
}

message("Wrote ", out_all, " (", nrow(combined), " rows)")
